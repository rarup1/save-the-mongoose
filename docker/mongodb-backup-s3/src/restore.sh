#!/bin/bash
#
# MongoDB Restore Script
# Restores MongoDB database from S3-compatible storage
#

set -e

# Source environment validation
source /usr/local/bin/env.sh

echo "=========================================="
echo "MongoDB Restore from S3"
echo "=========================================="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Check if BACKUP_FILE is specified
if [ -z "$BACKUP_FILE" ]; then
    echo "ERROR: BACKUP_FILE environment variable must be set"
    echo ""
    echo "Available backups in S3:"
    aws s3 ls ${AWS_ARGS} "s3://${S3_BUCKET}/${S3_PREFIX}" || echo "Could not list S3 contents"
    echo ""
    echo "Usage:"
    echo "  Set BACKUP_FILE to the filename you want to restore"
    echo "  Example: BACKUP_FILE=mongodb_backup_20251026_083428.archive"
    exit 1
fi

# Build S3 path
S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}${BACKUP_FILE}"
RESTORE_PATH="/tmp/${BACKUP_FILE}"

echo "Restore configuration:"
echo "  Source: ${S3_PATH}"
echo "  Target: ${MONGODB_HOST}:${MONGODB_PORT}"
echo ""

# Confirmation prompt (can be skipped with SKIP_CONFIRM=true)
if [ "${SKIP_CONFIRM}" != "true" ]; then
    echo "WARNING: This will restore data to MongoDB and may overwrite existing data!"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Restore cancelled by user"
        exit 0
    fi
fi

# Download backup from S3
echo "Downloading backup from S3..."
echo "Source: ${S3_PATH}"
echo ""

if ! aws s3 cp ${AWS_ARGS} "${S3_PATH}" "${RESTORE_PATH}"; then
    echo "ERROR: Failed to download backup from S3"
    exit 1
fi

# Verify download
if [ ! -f "${RESTORE_PATH}" ]; then
    echo "ERROR: Downloaded file not found"
    exit 1
fi

echo ""
echo "Backup downloaded successfully:"
ls -lh "${RESTORE_PATH}"
echo ""

# Build mongorestore command
echo "Building mongorestore command..."
MONGORESTORE_CMD="mongorestore"
MONGORESTORE_CMD="${MONGORESTORE_CMD} --host=${MONGODB_HOST}"
MONGORESTORE_CMD="${MONGORESTORE_CMD} --port=${MONGODB_PORT}"

# Add authentication if configured
if [ -n "$MONGODB_USER" ]; then
    MONGORESTORE_CMD="${MONGORESTORE_CMD} --username=${MONGODB_USER}"
    MONGORESTORE_CMD="${MONGORESTORE_CMD} --password=${MONGODB_PASSWORD}"
    MONGORESTORE_CMD="${MONGORESTORE_CMD} --authenticationDatabase=${MONGODB_AUTH_DB:-admin}"
fi

# Add archive and other options
MONGORESTORE_CMD="${MONGORESTORE_CMD} --archive=${RESTORE_PATH}"
MONGORESTORE_CMD="${MONGORESTORE_CMD} --gzip"

# Drop existing collections before restore (optional, controlled by DROP_BEFORE_RESTORE)
if [ "${DROP_BEFORE_RESTORE}" = "true" ]; then
    echo "WARNING: DROP_BEFORE_RESTORE is enabled - existing collections will be dropped"
    MONGORESTORE_CMD="${MONGORESTORE_CMD} --drop"
fi

# Execute restore
echo ""
echo "Executing MongoDB restore..."
echo "Command: mongorestore --host=${MONGODB_HOST} --port=${MONGODB_PORT} [auth options] --archive=${RESTORE_PATH} --gzip"
echo ""

if ! eval "${MONGORESTORE_CMD}"; then
    echo "ERROR: mongorestore failed"
    rm -f "${RESTORE_PATH}"
    exit 1
fi

echo ""
echo "Restore completed successfully!"
echo ""

# Cleanup downloaded backup file
echo "Cleaning up downloaded backup file..."
rm -f "${RESTORE_PATH}"
echo "Downloaded backup file removed"
echo ""

echo "=========================================="
echo "Restore completed successfully!"
echo "Completed at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=========================================="
echo ""

exit 0
