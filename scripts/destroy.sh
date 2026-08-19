#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# AVRE Client Teardown Script (Destructive & Automated)
#
# Usage:
#   ./scripts/destroy.sh <environment>
#   ./scripts/destroy.sh sandbox3
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
# 1. Argument Parsing & Config Validation
# ============================================================
if [[ $# -lt 1 ]]; then
    echo "Usage:"
    echo "  ./scripts/destroy.sh <environment>"
    echo
    exit 1
fi

ENV_NAME="$1"
CONFIG_FILE="$REPO_ROOT/config/${ENV_NAME}.json"

# Strict Rule: Config JSON file MUST exist! Otherwise NO GO.
if [[ ! -f "$CONFIG_FILE" ]]; then
    fail "Configuration file '$CONFIG_FILE' not found. You must run destroy.sh BEFORE deleting the environment config. If already deleted, please temporarily restore it or create a dummy config with the region (e.g., {\"aws_region\": \"ap-south-1\"})."
fi

# Parse deploy-time inputs from config
CFG_AWS_REGION="$(get_json_field "aws_region" "$CONFIG_FILE")"

# Validate region input
if [[ -z "$CFG_AWS_REGION" ]]; then
    fail "Missing required 'aws_region' in '$CONFIG_FILE'."
fi

readonly AWS_REGION="${AWS_REGION:-$CFG_AWS_REGION}"

# Derive infrastructure values by convention
readonly TG_DIR="${TG_DIR:-$REPO_ROOT/live/nonprod/${ENV_NAME}}"
readonly SECRET_NAME="${SECRET_NAME:-avre-${ENV_NAME}-ghcr-credentials}"

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
echo " AVRE Client Teardown (Destructive)"
echo "=========================================="
echo "Config File    : $CONFIG_FILE"
echo "Environment    : $ENV_NAME"
echo "AWS Region     : $AWS_REGION"
echo "Secret Name    : $SECRET_NAME"
echo "Terragrunt Dir : $TG_DIR"
echo

# ============================================================
# 2. Tool Availability Check
# ============================================================
echo "Checking required CLI tools..."
for tool in aws terragrunt; do
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
# 4. Teardown Safety Confirmation
# ============================================================
if [[ "${CI:-false}" == "true" ]]; then
    echo "Running in CI mode (CI=true). Bypassing interactive approval."
else
    echo "WARNING: This will completely destroy all infrastructure for '$ENV_NAME' and clean up GHCR credentials secrets."
    read -r -p "Are you sure you want to proceed with teardown? [y/N]: " APPROVE

    if [[ ! "$APPROVE" =~ ^[Yy]$ ]]; then
        echo
        echo "Teardown cancelled by user."
        exit 0
    fi
fi

# ============================================================
# 5. Terragrunt Teardown (Destructive)
# ============================================================
if [[ -d "$TG_DIR" ]]; then
    echo "=========================================="
    echo " Running Terragrunt Destroy"
    echo "=========================================="
    cd "$TG_DIR"
    
    # We pass dummy values for variables to satisfy OpenTofu validation requirements
    terragrunt destroy \
        -var="container_image=dummy" \
        -var="app_version=dummy" \
        -auto-approve
else
    echo "Terragrunt directory '$TG_DIR' not found. Skipping infrastructure destroy."
fi
echo

# ============================================================
# 6. AWS Secrets Manager Secret Cleanup (PAT credentials)
# ============================================================
echo "Checking for GHCR secret '$SECRET_NAME' in AWS Secrets Manager..."
if aws_cmd secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    >/dev/null 2>&1; then
    
    echo "Deleting secret '$SECRET_NAME'..."
    aws_cmd secretsmanager delete-secret \
        --secret-id "$SECRET_NAME" \
        --force-delete-without-recovery \
        --region "$AWS_REGION" \
        >/dev/null || fail "Failed to delete secret '$SECRET_NAME' from AWS Secrets Manager."
        
    echo "Secret '$SECRET_NAME' deleted successfully."
else
    echo "Secret '$SECRET_NAME' does not exist in AWS Secrets Manager. Skipping."
fi

echo
echo "=========================================="
echo " AVRE Teardown Complete."
echo "=========================================="
echo "Done."
