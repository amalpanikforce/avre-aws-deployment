#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# AVRE Client Deployment
#
# Usage:
#   ./scripts/deploy.sh v1.1.0
#
# First deployment:
#   - AWS authentication required
#   - GHCR username required
#   - GHCR PAT required
#   - Secret created in AWS Secrets Manager
#
# Later deployments:
#   ./scripts/deploy.sh v1.1.1
#   - Existing GHCR secret reused
#   - No PAT prompt
#
# Requirements:
#   - bash
#   - aws
#   - docker
#   - terragrunt
#
# Environment:
#   AWS_REGION
#   AWS_PROFILE
#   SECRET_NAME
#   GHCR_IMAGE
#   TG_DIR
#   AWS_NO_VERIFY_SSL
# ============================================================

readonly AWS_REGION="${AWS_REGION:-ap-south-1}"
readonly SECRET_NAME="${SECRET_NAME:-avre-sandbox3-ghcr-credentials}"
readonly GHCR_IMAGE="${GHCR_IMAGE:-ghcr.io/kcs-platform-engineering/avre}"

# Directory containing the sandbox Terragrunt configuration.
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly TG_DIR="${TG_DIR:-$REPO_ROOT/live/nonprod/sandbox3}"

readonly AWS_NO_VERIFY_SSL="${AWS_NO_VERIFY_SSL:-true}"

cleanup() {
    unset GHCR_TOKEN
    unset SECRET_JSON
    unset STORED_SECRET
}

trap cleanup EXIT

# ============================================================
# Functions
# ============================================================

aws_args() {
    if [[ "$AWS_NO_VERIFY_SSL" == "true" ]]; then
        printf '%s\n' "--no-verify-ssl"
    fi
}

aws_cmd() {
    local args=()

    if [[ "$AWS_NO_VERIFY_SSL" == "true" ]]; then
        args+=(--no-verify-ssl)
    fi

    aws "$@" "${args[@]}"
}

fail() {
    echo
    echo "ERROR: $1"
    echo
    exit 1
}

# ============================================================
# Header
# ============================================================

echo "=========================================="
echo " AVRE Client Deployment"
echo "=========================================="
echo

# ============================================================
# 1. Version
# ============================================================

if [[ $# -ne 1 ]]; then
    echo "Usage:"
    echo
    echo "  ./scripts/deploy.sh v1.1.0"
    echo
    exit 1
fi

VERSION="$1"

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "Invalid version '$VERSION'. Expected format: v1.1.0"
fi

IMAGE="${GHCR_IMAGE}:${VERSION}"

echo "Version    : $VERSION"
echo "Image      : $IMAGE"
echo "AWS Region : $AWS_REGION"
echo "Secret     : $SECRET_NAME"
echo "TG Dir     : $TG_DIR"
echo

# ============================================================
# 2. Required commands
# ============================================================

echo "Checking required tools..."

for command in aws docker terragrunt; do
    if ! command -v "$command" >/dev/null 2>&1; then
        fail "'$command' is required."
    fi
done

echo "Tools OK."
echo

# ============================================================
# 3. Check AWS authentication
# ============================================================

echo "Checking AWS credentials..."

AWS_ACCOUNT_ID="$(
    aws_cmd sts get-caller-identity \
        --query Account \
        --output text \
        --region "$AWS_REGION" \
        2>/dev/null
)" || fail "AWS credentials are not configured or invalid."

AWS_ARN="$(
    aws_cmd sts get-caller-identity \
        --query Arn \
        --output text \
        --region "$AWS_REGION"
)"

echo "AWS Account  : $AWS_ACCOUNT_ID"
echo "AWS Identity : $AWS_ARN"
echo

# ============================================================
# 4. Check/create GHCR secret
# ============================================================

echo "Checking GHCR credentials..."

SECRET_EXISTS=false

if aws_cmd secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    >/dev/null 2>&1; then

    SECRET_EXISTS=true
fi

if [[ "$SECRET_EXISTS" == "true" ]]; then

    echo "Existing GHCR secret found."
    echo

else

    echo "GHCR secret does not exist."
    echo
    echo "Initial GHCR setup required."
    echo

    read -r -p "GitHub username: " GHCR_USERNAME

    [[ -n "$GHCR_USERNAME" ]] || fail "GitHub username cannot be empty."

    read -r -s -p "GitHub PAT (read:packages): " GHCR_TOKEN
    echo

    [[ -n "$GHCR_TOKEN" ]] || fail "GitHub PAT cannot be empty."

    echo
    echo "Testing GHCR credentials..."

    if ! printf '%s' "$GHCR_TOKEN" | docker login ghcr.io \
        --username "$GHCR_USERNAME" \
        --password-stdin \
        >/dev/null; then

        fail "GHCR authentication failed."
    fi

    echo "GHCR authentication successful."

    # Create JSON without jq.
    SECRET_JSON=$(printf \
        '{"username":"%s","password":"%s"}' \
        "$GHCR_USERNAME" \
        "$GHCR_TOKEN"
    )

    echo "Creating AWS Secrets Manager secret..."

    aws_cmd secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "GHCR credentials for AVRE ECS deployment" \
        --secret-string "$SECRET_JSON" \
        --region "$AWS_REGION" \
        >/dev/null

    echo "GHCR secret created."
    echo

    docker logout ghcr.io >/dev/null 2>&1 || true
fi

# ============================================================
# 5. Get secret ARN
# ============================================================

SECRET_ARN="$(
    aws_cmd secretsmanager describe-secret \
        --secret-id "$SECRET_NAME" \
        --query ARN \
        --output text \
        --region "$AWS_REGION"
)"

echo "Secret ARN:"
echo "  $SECRET_ARN"
echo

# ============================================================
# 6. Login using existing secret
#
# This allows validation of private GHCR access without
# printing the credential.
# ============================================================

echo "Validating GHCR access..."

STORED_SECRET="$(
    aws_cmd secretsmanager get-secret-value \
        --secret-id "$SECRET_NAME" \
        --query SecretString \
        --output text \
        --region "$AWS_REGION"
)"

[[ -n "$STORED_SECRET" ]] || fail "GHCR secret is empty."

# Extract username/password without jq.
#
# Expected JSON:
# {"username":"...","password":"..."}
#
# Python is intentionally avoided.
# AWS secret is validated by attempting GHCR login.

GHCR_USERNAME="$(
    printf '%s' "$STORED_SECRET" |
        sed -n 's/.*"username":"\([^"]*\)".*/\1/p'
)"

GHCR_TOKEN="$(
    printf '%s' "$STORED_SECRET" |
        sed -n 's/.*"password":"\([^"]*\)".*/\1/p'
)"

[[ -n "$GHCR_USERNAME" ]] || fail "GHCR username missing from secret."
[[ -n "$GHCR_TOKEN" ]] || fail "GHCR password missing from secret."

if ! printf '%s' "$GHCR_TOKEN" | docker login ghcr.io \
    --username "$GHCR_USERNAME" \
    --password-stdin \
    >/dev/null; then

    fail "Stored GHCR credentials are invalid or expired."
fi

echo "GHCR access OK."
echo

# ============================================================
# 7. Verify requested version
# ============================================================

echo "Checking requested image..."

if ! docker manifest inspect "$IMAGE" >/dev/null 2>&1; then

    docker logout ghcr.io >/dev/null 2>&1 || true

    fail "Image version does not exist or is inaccessible: $IMAGE"
fi

echo "Image exists:"
echo "  $IMAGE"
echo

# ============================================================
# 8. Resolve immutable multi-platform digest
# ============================================================

echo "Resolving immutable image digest..."

IMAGE_DIGEST="$(
    docker buildx imagetools inspect "$IMAGE" |
        awk '/^Digest:/ {print $2; exit}'
)"

[[ -n "$IMAGE_DIGEST" ]] ||
    fail "Could not resolve image digest."

echo "Image digest:"
echo "  $IMAGE_DIGEST"
echo

# ============================================================
# 9. Verify digest
# ============================================================

echo "Verifying immutable digest..."

if ! docker manifest inspect \
    "${GHCR_IMAGE}@${IMAGE_DIGEST}" \
    >/dev/null 2>&1; then

    docker logout ghcr.io >/dev/null 2>&1 || true

    fail "Resolved digest does not exist: $IMAGE_DIGEST"
fi

echo "Digest verified."
echo

docker logout ghcr.io >/dev/null 2>&1 || true

# ============================================================
# 10. Check Terragrunt directory
# ============================================================

[[ -d "$TG_DIR" ]] ||
    fail "Terragrunt directory does not exist: $TG_DIR"

cd "$TG_DIR"

echo "Terragrunt directory:"
echo "  $TG_DIR"
echo

# ============================================================
# 11. Plan
# ============================================================

echo "=========================================="
echo " Terraform/OpenTofu Plan"
echo "=========================================="
echo

echo "Deploying:"
echo
echo "  Version : $VERSION"
echo "  Image   : ${GHCR_IMAGE}@${IMAGE_DIGEST}"
echo

terragrunt plan \
    -var="container_image=${GHCR_IMAGE}@${IMAGE_DIGEST}" \
    -var="repository_credentials_arn=${SECRET_ARN}"

# ============================================================
# 12. Approval
# ============================================================

echo
echo "=========================================="
echo " Deployment Approval"
echo "=========================================="
echo

read -r -p "Deploy $VERSION to ECS? [y/N]: " APPROVE

if [[ ! "$APPROVE" =~ ^[Yy]$ ]]; then
    echo
    echo "Deployment cancelled."
    exit 0
fi

# ============================================================
# 13. Apply
# ============================================================

echo
echo "=========================================="
echo " Applying Deployment"
echo "=========================================="
echo

terragrunt apply \
    -var="container_image=${GHCR_IMAGE}@${IMAGE_DIGEST}" \
    -var="repository_credentials_arn=${SECRET_ARN}"

# ============================================================
# 14. Finish
# ============================================================

echo
echo "=========================================="
echo " AVRE Deployment Complete"
echo "=========================================="
echo
echo "Version:"
echo "  $VERSION"
echo
echo "Image:"
echo "  ${GHCR_IMAGE}@${IMAGE_DIGEST}"
echo
echo "Secret:"
echo "  $SECRET_ARN"
echo
echo "Environment:"
echo "  $TG_DIR"
echo
echo "Done."