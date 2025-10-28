#!/bin/bash
#
# Environment variable validation and setup for MongoDB backup/restore
#

set -e

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Track if there are any errors
HAS_ERRORS=0

# Helper functions
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    HAS_ERRORS=1
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
}

info() {
    echo -e "${GREEN}INFO: $1${NC}"
}

# Validate required environment variables
validate_required() {
    local var_name=$1
    local var_value="${!var_name}"

    if [ -z "$var_value" ]; then
        error "Required environment variable '$var_name' is not set"
        return 1
    fi
    return 0
}

# Validate optional environment variables with defaults
validate_optional() {
    local var_name=$1
    local default_value=$2
    local var_value="${!var_name}"

    if [ -z "$var_value" ]; then
        warn "Optional environment variable '$var_name' not set, using default: '$default_value'"
        export "$var_name=$default_value"
    fi
}

echo "=========================================="
echo "MongoDB Backup/Restore - Environment Setup"
echo "=========================================="
echo ""

# MongoDB connection settings
info "Validating MongoDB connection settings..."
validate_required "MONGODB_HOST"
validate_optional "MONGODB_PORT" "27017"

# MongoDB authentication (optional but recommended)
if [ -n "$MONGODB_USER" ]; then
    info "MongoDB authentication enabled"
    validate_required "MONGODB_PASSWORD"
    validate_optional "MONGODB_AUTH_DB" "admin"
else
    warn "No MongoDB authentication configured (MONGODB_USER not set)"
fi

# S3 settings
echo ""
info "Validating S3 settings..."
validate_required "S3_BUCKET"
validate_required "AWS_ACCESS_KEY_ID"
validate_required "AWS_SECRET_ACCESS_KEY"

validate_optional "S3_REGION" "us-east-1"
validate_optional "S3_PREFIX" ""
validate_optional "S3_FORCE_PATH_STYLE" "false"
validate_optional "S3_USE_SSL" "true"

# S3 endpoint (optional - for MinIO or other S3-compatible services)
if [ -n "$S3_ENDPOINT" ]; then
    info "Using custom S3 endpoint: $S3_ENDPOINT"
else
    info "Using default AWS S3 endpoint"
fi

# Backup/Restore settings
validate_optional "BACKUP_RETENTION_DAYS" "30"

# Check if there were any errors
echo ""
if [ $HAS_ERRORS -eq 1 ]; then
    error "Environment validation failed. Please fix the errors above."
    exit 1
fi

# Configure AWS CLI
echo "=========================================="
echo "Configuring AWS CLI..."
echo "=========================================="
export AWS_DEFAULT_REGION="${S3_REGION}"

if [ "${S3_FORCE_PATH_STYLE}" = "true" ]; then
    info "Configuring AWS CLI for path-style addressing (required for MinIO)"
    aws configure set default.s3.addressing_style path
fi

# Build endpoint URL if custom endpoint is specified
if [ -n "${S3_ENDPOINT}" ]; then
    if [ "${S3_USE_SSL}" = "true" ]; then
        export ENDPOINT_URL="https://${S3_ENDPOINT}"
    else
        export ENDPOINT_URL="http://${S3_ENDPOINT}"
    fi
    export AWS_ARGS="--endpoint-url=${ENDPOINT_URL}"
    info "S3 endpoint URL: ${ENDPOINT_URL}"
else
    export AWS_ARGS=""
fi

echo ""
info "Environment validation completed successfully"
echo "=========================================="
echo ""
echo "Configuration Summary:"
echo "  MongoDB: ${MONGODB_HOST}:${MONGODB_PORT}"
echo "  S3 Bucket: s3://${S3_BUCKET}/${S3_PREFIX}"
echo "  S3 Region: ${S3_REGION}"
if [ -n "$S3_ENDPOINT" ]; then
    echo "  S3 Endpoint: ${ENDPOINT_URL}"
fi
echo "=========================================="
echo ""
