#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# AVRE GHCR Secret Bootstrap
#
# Creates or updates the AWS Secrets Manager secret used by
# ECS to authenticate against GitHub Container Registry (GHCR).
#
# Requirements:
#   - bash
#   - aws CLI
#   - docker
#
# Usage:
#   ./scripts/setup-ghcr-secret.sh
#
# Optional:
#   AWS_REGION=ap-south-1 \
#   SECRET_NAME=avre-sandbox-ghcr-credentials \
#   GHCR_IMAGE=ghcr.io/kcs-platform-engineering/avre \
#   ./scripts/setup-ghcr-secret.sh
# ============================================================

set -o pipefail

readonly AWS_REGION="${AWS_REGION:-ap-south-1}"
readonly SECRET_NAME="${SECRET_NAME:-avre-sandbox-ghcr-credentials}"
readonly GHCR_IMAGE="${GHCR_IMAGE:-ghcr.io/kcs-platform-engineering/avre}"

# Temporary corporate SSL workaround
readonly AWS_NO_VERIFY_SSL="${AWS_NO_VERIFY_SSL:-true}"

if [[ "$AWS_NO_VERIFY_SSL" == "true" ]]; then
    export PYTHONWARNINGS="ignore"
fi

cleanup() {
    unset GHCR_TOKEN
    unset SECRET_JSON
    unset STORED_SECRET
}

trap cleanup EXIT

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

echo "=========================================="
echo " AVRE GHCR Secret Setup"
echo "=========================================="
echo

# ------------------------------------------------------------
# 1. Check required commands
# ------------------------------------------------------------

for command in aws docker; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: '$command' is required."
        echo
        exit 1
    fi
done

echo "AWS Region : $AWS_REGION"
echo "Secret     : $SECRET_NAME"
echo "GHCR Image : $GHCR_IMAGE"
echo

# ------------------------------------------------------------
# 2. Check AWS credentials
# ------------------------------------------------------------

echo "Checking AWS credentials..."

AWS_ACCOUNT_ID="$(
    aws_cmd sts get-caller-identity \
        --query Account \
        --output text \
        --region "$AWS_REGION" \
        2>/dev/null
)" || {
    echo "ERROR: AWS credentials are not configured or invalid."
    exit 1
}

AWS_ARN="$(
    aws_cmd sts get-caller-identity \
        --query Arn \
        --output text \
        --region "$AWS_REGION" \
        2>/dev/null
)"

echo "AWS Account: $AWS_ACCOUNT_ID"
echo "AWS Identity: $AWS_ARN"
echo

# ------------------------------------------------------------
# 3. Read GitHub username
# ------------------------------------------------------------

read -r -p "GitHub username: " GHCR_USERNAME

if [[ -z "$GHCR_USERNAME" ]]; then
    echo "ERROR: GitHub username cannot be empty."
    exit 1
fi

# ------------------------------------------------------------
# 4. Read GitHub PAT securely
# ------------------------------------------------------------

read -r -s -p "GitHub PAT (read:packages): " GHCR_TOKEN
echo

if [[ -z "$GHCR_TOKEN" ]]; then
    echo "ERROR: GitHub PAT cannot be empty."
    exit 1
fi

# ------------------------------------------------------------
# 5. Login to GHCR
# ------------------------------------------------------------

echo
echo "Authenticating with GHCR..."

if ! printf '%s' "$GHCR_TOKEN" | docker login ghcr.io \
    --username "$GHCR_USERNAME" \
    --password-stdin \
    >/dev/null; then

    echo "ERROR: GHCR authentication failed."
    echo
    echo "Check:"
    echo "  - GitHub username"
    echo "  - GitHub PAT"
    echo "  - PAT has read:packages permission"
    echo
    exit 1
fi

echo "GHCR authentication successful."
echo

# ------------------------------------------------------------
# 6. Verify GHCR image exists
# ------------------------------------------------------------

echo "Checking GHCR image..."

if ! docker manifest inspect \
    "$GHCR_IMAGE:1.0.2" \
    >/dev/null 2>&1; then

    echo "ERROR: GHCR image does not exist or cannot be accessed:"
    echo "  $GHCR_IMAGE:1.0.2"
    echo
    exit 1
fi

echo "GHCR image exists."
echo

# ------------------------------------------------------------
# 7. Get current multi-architecture digest
# ------------------------------------------------------------

echo "Reading GHCR image digest..."

IMAGE_DIGEST="$(
    docker buildx imagetools inspect "$GHCR_IMAGE:1.0.2" 2>/dev/null |
        awk '/^Digest:/ {print $2; exit}'
)"

if [[ -z "$IMAGE_DIGEST" ]]; then
    echo "ERROR: Could not determine GHCR image digest."
    echo
    exit 1
fi

echo "GHCR index digest:"
echo "  $IMAGE_DIGEST"
echo

# ------------------------------------------------------------
# 8. Verify exact digest exists
# ------------------------------------------------------------

echo "Verifying image digest..."

if ! docker manifest inspect \
    "${GHCR_IMAGE}@${IMAGE_DIGEST}" \
    >/dev/null 2>&1; then

    echo "ERROR: Digest does not exist in GHCR:"
    echo "  $IMAGE_DIGEST"
    echo
    exit 1
fi

echo "Image digest verified."
echo

# ------------------------------------------------------------
# 9. Create valid JSON
# ------------------------------------------------------------

SECRET_JSON=$(printf \
    '{"username":"%s","password":"%s"}' \
    "$GHCR_USERNAME" \
    "$GHCR_TOKEN"
)

# ------------------------------------------------------------
# 10. Check whether secret exists
# ------------------------------------------------------------

echo "Checking AWS Secrets Manager..."

SECRET_EXISTS=false

if aws_cmd secretsmanager describe-secret \
    --secret-id "$SECRET_NAME" \
    --region "$AWS_REGION" \
    >/dev/null 2>&1; then

    SECRET_EXISTS=true
fi

# ------------------------------------------------------------
# 11. Create or update secret
# ------------------------------------------------------------

if [[ "$SECRET_EXISTS" == "true" ]]; then

    echo "Updating existing secret..."

    aws_cmd secretsmanager put-secret-value \
        --secret-id "$SECRET_NAME" \
        --secret-string "$SECRET_JSON" \
        --region "$AWS_REGION" \
        >/dev/null

    echo "Secret updated."

else

    echo "Creating new secret..."

    aws_cmd secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "GHCR credentials for AVRE ECS deployment" \
        --secret-string "$SECRET_JSON" \
        --region "$AWS_REGION" \
        >/dev/null

    echo "Secret created."
fi

echo

# ------------------------------------------------------------
# 12. Get secret ARN
# ------------------------------------------------------------

SECRET_ARN="$(
    aws_cmd secretsmanager describe-secret \
        --secret-id "$SECRET_NAME" \
        --query ARN \
        --output text \
        --region "$AWS_REGION" \
        2>/dev/null
)"

echo "Secret ARN:"
echo "  $SECRET_ARN"
echo

# ------------------------------------------------------------
# 13. Verify stored secret
# ------------------------------------------------------------

echo "Validating stored secret..."

STORED_SECRET="$(
    aws_cmd secretsmanager get-secret-value \
        --secret-id "$SECRET_NAME" \
        --query SecretString \
        --output text \
        --region "$AWS_REGION" \
        2>/dev/null
)"

if [[ "$STORED_SECRET" != \{\"username\":\"*\"\,\"password\":\"*\"\} ]]; then
    echo "ERROR: Stored secret is not valid GHCR JSON."
    echo
    exit 1
fi

echo "Secret JSON valid."
echo

# ------------------------------------------------------------
# 14. Print deployment values
# ------------------------------------------------------------

echo "=========================================="
echo " Setup Complete"
echo "=========================================="
echo
echo "Secret ARN:"
echo "$SECRET_ARN"
echo
echo "Image:"
echo "${GHCR_IMAGE}@${IMAGE_DIGEST}"
echo

docker logout ghcr.io >/dev/null 2>&1 || true

echo "GHCR logout complete."
echo "Done."