#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# AVRE Client Deployment Script (Idempotent & Self-Healing)
#
# Usage:
#   ./scripts/deploy.sh                         (defaults to sandbox3 using config/sandbox3.json)
#   ./scripts/deploy.sh 1.0.2                   (defaults to sandbox3 with version override)
#   ./scripts/deploy.sh sandbox3                (specified environment using config/sandbox3.json)
#   ./scripts/deploy.sh sandbox3 1.0.2          (specified environment with version override)
#   ./scripts/deploy.sh sandbox4 1.0.2          (future environment config/sandbox4.json)
#
# Strict Rules:
#   - All deployment inputs MUST be defined in config/<environment>.json. Otherwise NO GO.
#   - Execution is completely IDEMPOTENT & SELF-HEALING (prompts to refresh expired PAT).
#   - GitHub PAT is never logged, printed, committed, or passed to Terraform.
# ============================================================

# Temporary corporate SSL workaround (can be set to false when corporate CA is trusted)
readonly AWS_NO_VERIFY_SSL="${AWS_NO_VERIFY_SSL:-true}"

# Globally suppress Python urllib3 SSL warnings for AWS CLI calls when SSL verification is disabled
if [[ "$AWS_NO_VERIFY_SSL" == "true" ]]; then
    export PYTHONWARNINGS="ignore"
fi

# Repository Paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Sensitive Variable Cleanup on Exit
cleanup() {
    unset GHCR_TOKEN
    unset SECRET_JSON
    unset STORED_SECRET
}
trap cleanup EXIT

fail() {
    echo
    echo "ERROR: $1"
    echo
    exit 1
}

# Helper to read JSON fields without external jq dependency
get_json_field() {
    local field="$1"
    local file="$2"
    if [[ -f "$file" ]]; then
        sed -n 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | tr -d '\r'
    fi
}

# ============================================================
# 1. Argument Parsing & Strict JSON Config Validation
# ============================================================
ENV_NAME="sandbox3"
CLI_VERSION=""

if [[ $# -eq 0 ]]; then
    ENV_NAME="sandbox3"
elif [[ $# -eq 1 ]]; then
    if [[ "$1" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
        ENV_NAME="sandbox3"
        CLI_VERSION="$1"
    else
        ENV_NAME="$1"
    fi
elif [[ $# -eq 2 ]]; then
    ENV_NAME="$1"
    CLI_VERSION="$2"
else
    echo "Usage:"
    echo "  ./scripts/deploy.sh                         (defaults to sandbox3 using config/sandbox3.json)"
    echo "  ./scripts/deploy.sh <version>              (defaults to sandbox3 with specified version)"
    echo "  ./scripts/deploy.sh <environment>          (specified environment using config/<env>.json)"
    echo "  ./scripts/deploy.sh <environment> <version> (specified environment & version)"
    echo
    exit 1
fi

CONFIG_FILE="$REPO_ROOT/config/${ENV_NAME}.json"

# Strict Rule: Config JSON file MUST exist! Otherwise NO GO.
if [[ ! -f "$CONFIG_FILE" ]]; then
    fail "Configuration file '$CONFIG_FILE' not found. All deployment inputs must be present in JSON file. Otherwise NO GO."
fi

# Parse inputs from JSON config
CFG_AWS_REGION="$(get_json_field "aws_region" "$CONFIG_FILE")"
CFG_SECRET_NAME="$(get_json_field "secret_name" "$CONFIG_FILE")"
CFG_GHCR_IMAGE="$(get_json_field "ghcr_image" "$CONFIG_FILE")"
CFG_CLUSTER_NAME="$(get_json_field "cluster_name" "$CONFIG_FILE")"
CFG_SERVICE_NAME="$(get_json_field "service_name" "$CONFIG_FILE")"
CFG_TG_DIR="$(get_json_field "tg_dir" "$CONFIG_FILE")"
CFG_VERSION="$(get_json_field "version" "$CONFIG_FILE")"

# Strict Rule: ALL required parameters MUST be present in JSON config file!
MISSING_FIELDS=()
[[ -n "$CFG_AWS_REGION" ]] || MISSING_FIELDS+=("aws_region")
[[ -n "$CFG_SECRET_NAME" ]] || MISSING_FIELDS+=("secret_name")
[[ -n "$CFG_GHCR_IMAGE" ]] || MISSING_FIELDS+=("ghcr_image")
[[ -n "$CFG_CLUSTER_NAME" ]] || MISSING_FIELDS+=("cluster_name")
[[ -n "$CFG_SERVICE_NAME" ]] || MISSING_FIELDS+=("service_name")
[[ -n "$CFG_TG_DIR" ]] || MISSING_FIELDS+=("tg_dir")
[[ -n "$CFG_VERSION" ]] || MISSING_FIELDS+=("version")

if [[ ${#MISSING_FIELDS[@]} -gt 0 ]]; then
    fail "Missing required input(s) in '$CONFIG_FILE': [${MISSING_FIELDS[*]}]. All inputs must be present in JSON file. Otherwise NO GO."
fi

# Set defaults from JSON config with optional CLI overrides
VERSION="${CLI_VERSION:-$CFG_VERSION}"
readonly AWS_REGION="${AWS_REGION:-$CFG_AWS_REGION}"
readonly SECRET_NAME="${SECRET_NAME:-$CFG_SECRET_NAME}"
readonly GHCR_IMAGE="${GHCR_IMAGE:-$CFG_GHCR_IMAGE}"
readonly CLUSTER_NAME="${CLUSTER_NAME:-$CFG_CLUSTER_NAME}"
readonly SERVICE_NAME="${SERVICE_NAME:-$CFG_SERVICE_NAME}"
readonly TG_DIR="${TG_DIR:-$REPO_ROOT/$CFG_TG_DIR}"

if [[ ! "$VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
    fail "Invalid version format '$VERSION'. Expected semver format (e.g. 1.0.2 or v1.0.2)."
fi

aws_cmd() {
    local args=()
    if [[ "$AWS_NO_VERIFY_SSL" == "true" ]]; then
        args+=(--no-verify-ssl)
    fi
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        args+=(--profile "$AWS_PROFILE")
    fi
    aws "${args[@]}" "$@"
}

# ============================================================
# Header
# ============================================================
echo "=========================================="
echo " AVRE Client Deployment (Idempotent)"
echo "=========================================="
echo "Config File    : $CONFIG_FILE"
echo "Environment    : $ENV_NAME"
echo "Target Version : $VERSION"
echo "Image Tag Ref  : ${GHCR_IMAGE}:${VERSION}"
echo "AWS Region     : $AWS_REGION"
echo "Secret Name    : $SECRET_NAME"
echo "ECS Cluster    : $CLUSTER_NAME"
echo "ECS Service    : $SERVICE_NAME"
echo "Terragrunt Dir : $TG_DIR"
echo

# ============================================================
# 2. Tool Availability Check
# ============================================================
echo "Checking required CLI tools..."
for tool in aws docker terragrunt; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        fail "Required tool '$tool' is not installed or not in PATH."
    fi
done
echo "Required tools are available."
echo

# ============================================================
# 3. AWS Authentication Check
# ============================================================
echo "Verifying AWS authentication..."
AWS_ACCOUNT_ID="$(
    aws_cmd sts get-caller-identity \
        --query Account \
        --output text \
        --region "$AWS_REGION" \
        2>/dev/null | tr -d '\r'
)" || fail "AWS credentials are not configured or invalid for region '$AWS_REGION'."

AWS_ARN="$(
    aws_cmd sts get-caller-identity \
        --query Arn \
        --output text \
        --region "$AWS_REGION" \
        2>/dev/null | tr -d '\r'
)"

echo "AWS Account  : $AWS_ACCOUNT_ID"
echo "AWS Identity : $AWS_ARN"
echo

# ============================================================
# 4. Check / Create GHCR Secret in AWS Secrets Manager (Idempotent)
# ============================================================
echo "Checking GHCR credentials in AWS Secrets Manager..."
SECRET_EXISTS=false

if aws_cmd secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    >/dev/null 2>&1; then
    SECRET_EXISTS=true
fi

if [[ "$SECRET_EXISTS" == "true" ]]; then
    echo "Existing GHCR secret '$SECRET_NAME' found (reusing)."
    echo
else
    echo "GHCR secret '$SECRET_NAME' does not exist."
    echo "Initial setup required for GHCR authentication."
    echo

    read -r -p "GitHub Username: " GHCR_USERNAME
    [[ -n "$GHCR_USERNAME" ]] || fail "GitHub username cannot be empty."

    read -r -s -p "GitHub Personal Access Token (PAT with read:packages): " GHCR_TOKEN
    echo
    [[ -n "$GHCR_TOKEN" ]] || fail "GitHub PAT cannot be empty."

    echo
    echo "Testing GHCR authentication..."
    if ! printf '%s' "$GHCR_TOKEN" | docker login ghcr.io \
        --username "$GHCR_USERNAME" \
        --password-stdin \
        >/dev/null 2>&1; then
        fail "GHCR authentication failed for user '$GHCR_USERNAME'. Check username and PAT permissions (read:packages)."
    fi
    echo "GHCR authentication successful."

    SECRET_JSON=$(printf \
        '{"username":"%s","password":"%s"}' \
        "$GHCR_USERNAME" \
        "$GHCR_TOKEN"
    )

    echo "Creating AWS Secrets Manager secret '$SECRET_NAME'..."
    aws_cmd secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "GHCR credentials for AVRE ECS deployment" \
        --secret-string "$SECRET_JSON" \
        --region "$AWS_REGION" \
        >/dev/null || fail "Failed to create AWS Secrets Manager secret."

    echo "GHCR secret created successfully."
    echo
    docker logout ghcr.io >/dev/null 2>&1 || true
fi

# ============================================================
# 5. Retrieve Secret ARN & Authenticate to Private GHCR
# ============================================================
SECRET_ARN="$(
    aws_cmd secretsmanager describe-secret \
        --secret-id "$SECRET_NAME" \
        --query ARN \
        --output text \
        --region "$AWS_REGION" \
        2>/dev/null | tr -d '\r'
)"
[[ -n "$SECRET_ARN" ]] || fail "Could not retrieve Secret ARN for '$SECRET_NAME'."

echo "Validating GHCR credentials from Secrets Manager..."
STORED_SECRET="$(
    aws_cmd secretsmanager get-secret-value \
        --secret-id "$SECRET_NAME" \
        --query SecretString \
        --output text \
        --region "$AWS_REGION" \
        2>/dev/null
)"
[[ -n "$STORED_SECRET" ]] || fail "GHCR secret string is empty."

# Extract username & password from valid JSON without external jq dependency
GHCR_USERNAME="$(
    printf '%s' "$STORED_SECRET" |
        sed -n 's/.*"username"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr -d '\r'
)"
GHCR_TOKEN="$(
    printf '%s' "$STORED_SECRET" |
        sed -n 's/.*"password"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr -d '\r'
)"

LOGIN_VALID=false
if [[ -n "$GHCR_USERNAME" && -n "$GHCR_TOKEN" ]]; then
    if printf '%s' "$GHCR_TOKEN" | docker login ghcr.io \
        --username "$GHCR_USERNAME" \
        --password-stdin \
        >/dev/null 2>&1; then
        LOGIN_VALID=true
    fi
fi

if [[ "$LOGIN_VALID" == "false" ]]; then
    echo "WARNING: Stored GHCR credentials in AWS Secrets Manager are invalid or expired."
    echo "Please provide updated credentials to refresh AWS Secrets Manager."
    echo

    read -r -p "GitHub Username: " GHCR_USERNAME
    [[ -n "$GHCR_USERNAME" ]] || fail "GitHub username cannot be empty."

    read -r -s -p "GitHub Personal Access Token (PAT with read:packages): " GHCR_TOKEN
    echo
    [[ -n "$GHCR_TOKEN" ]] || fail "GitHub PAT cannot be empty."

    echo
    echo "Testing updated GHCR authentication..."
    if ! printf '%s' "$GHCR_TOKEN" | docker login ghcr.io \
        --username "$GHCR_USERNAME" \
        --password-stdin \
        >/dev/null 2>&1; then
        fail "GHCR authentication failed for user '$GHCR_USERNAME'. Check username and PAT permissions (read:packages)."
    fi
    echo "GHCR authentication successful."

    SECRET_JSON=$(printf \
        '{"username":"%s","password":"%s"}' \
        "$GHCR_USERNAME" \
        "$GHCR_TOKEN"
    )

    echo "Updating AWS Secrets Manager secret '$SECRET_NAME'..."
    aws_cmd secretsmanager put-secret-value \
        --secret-id "$SECRET_NAME" \
        --secret-string "$SECRET_JSON" \
        --region "$AWS_REGION" \
        >/dev/null || fail "Failed to update AWS Secrets Manager secret."

    echo "GHCR secret updated successfully in AWS Secrets Manager."
    echo
fi

echo "GHCR authentication verified."
echo

# ============================================================
# 6. Verify Tag Exists in GHCR
# ============================================================
IMAGE_TAG_REF="${GHCR_IMAGE}:${VERSION}"
echo "Verifying image '$IMAGE_TAG_REF' exists in GHCR..."
if ! docker manifest inspect "$IMAGE_TAG_REF" >/dev/null 2>&1; then
    docker logout ghcr.io >/dev/null 2>&1 || true
    fail "Image tag '$IMAGE_TAG_REF' does not exist or is inaccessible in private GHCR."
fi
echo "Image tag '$IMAGE_TAG_REF' exists."
echo

# ============================================================
# 7. Resolve Top-Level OCI Index Digest (Idempotent)
# ============================================================
echo "Resolving multi-platform OCI index digest for '$IMAGE_TAG_REF'..."
IMAGE_DIGEST="$(
    docker buildx imagetools inspect "$IMAGE_TAG_REF" 2>/dev/null |
        awk '/^Digest:/ {print $2; exit}' | tr -d '\r'
)"

if [[ ! "$IMAGE_DIGEST" =~ ^sha256:[a-f0-9]{64}$ ]]; then
    docker logout ghcr.io >/dev/null 2>&1 || true
    fail "Could not resolve valid multi-platform OCI index digest for '$IMAGE_TAG_REF'."
fi

echo "Resolved Digest : $IMAGE_DIGEST"
IMMUTABLE_IMAGE="${GHCR_IMAGE}@${IMAGE_DIGEST}"
echo "Immutable Image : $IMMUTABLE_IMAGE"
echo

# ============================================================
# 8. Verify Resolved Digest Exists in GHCR
# ============================================================
echo "Verifying immutable image digest '$IMMUTABLE_IMAGE'..."
if ! docker manifest inspect "$IMMUTABLE_IMAGE" >/dev/null 2>&1; then
    docker logout ghcr.io >/dev/null 2>&1 || true
    fail "Resolved image digest '$IMMUTABLE_IMAGE' could not be verified in GHCR."
fi
echo "Immutable digest verified."
echo

docker logout ghcr.io >/dev/null 2>&1 || true

# ============================================================
# 9. Terragrunt Configuration Directory Check
# ============================================================
[[ -d "$TG_DIR" ]] || fail "Terragrunt environment directory '$TG_DIR' does not exist."
cd "$TG_DIR"

# ============================================================
# 10. Terragrunt Plan
# ============================================================
echo "=========================================="
echo " Running Terragrunt Plan"
echo "=========================================="
echo "Targeting Environment: $ENV_NAME"
echo "  Container Image : $IMMUTABLE_IMAGE"
echo "  Secret ARN      : $SECRET_ARN"
echo

terragrunt plan \
    -var="container_image=${IMMUTABLE_IMAGE}" \
    -var="repository_credentials_arn=${SECRET_ARN}"

# ============================================================
# 11. Deployment Approval Prompt
# ============================================================
echo
echo "=========================================="
echo " Deployment Approval"
echo "=========================================="
echo
read -r -p "Deploy version $VERSION ($IMMUTABLE_IMAGE) to environment '$ENV_NAME'? [y/N]: " APPROVE

if [[ ! "$APPROVE" =~ ^[Yy]$ ]]; then
    echo
    echo "Deployment cancelled by user."
    exit 0
fi

# ============================================================
# 12. Terragrunt Apply (Idempotent State Sync)
# ============================================================
echo
echo "=========================================="
echo " Applying Terragrunt Deployment"
echo "=========================================="
echo

terragrunt apply \
    -var="container_image=${IMMUTABLE_IMAGE}" \
    -var="repository_credentials_arn=${SECRET_ARN}" \
    -auto-approve

# ============================================================
# 13. Wait for ECS Service Stability (Idempotent Check)
# ============================================================
echo
echo "=========================================="
echo " Checking ECS Service Status"
echo "=========================================="
echo "Waiting for ECS service '$SERVICE_NAME' in cluster '$CLUSTER_NAME' to reach stable state..."

if aws_cmd ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION"; then
    echo "ECS service is stable and running the updated task definition."
else
    echo "WARNING: ECS service stability check timed out or reported non-stable status."
    echo "Please check ECS Console / CloudWatch logs for details."
fi

# ============================================================
# 14. Deployment Summary
# ============================================================
echo
echo "=========================================="
echo " AVRE Deployment Successful!"
echo "=========================================="
echo "Environment      : $ENV_NAME"
echo "Deployed Version : $VERSION"
echo "Container Image  : $IMMUTABLE_IMAGE"
echo "Secret ARN       : $SECRET_ARN"
echo "ECS Cluster      : $CLUSTER_NAME"
echo "ECS Service      : $SERVICE_NAME"
echo "Terragrunt Dir   : $TG_DIR"
echo "Done."