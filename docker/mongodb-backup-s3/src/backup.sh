#!/bin/bash
#
# MongoDB Backup Script
# Backs up MongoDB database to S3-compatible storage
#

set -e

# Source environment validation
source /usr/local/bin/env.sh

echo "=========================================="
echo "MongoDB Backup to S3"
echo "=========================================="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Generate backup filename with timestamp
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
BACKUP_FILE="mongodb_backup_${TIMESTAMP}.archive"
BACKUP_PATH="/tmp/${BACKUP_FILE}"

# Build mongodump command
echo "Building mongodump command..."
MONGODUMP_CMD="mongodump"
MONGODUMP_CMD="${MONGODUMP_CMD} --host=${MONGODB_HOST}"
MONGODUMP_CMD="${MONGODUMP_CMD} --port=${MONGODB_PORT}"

# Add authentication if configured
if [ -n "$MONGODB_USER" ]; then
    MONGODUMP_CMD="${MONGODUMP_CMD} --username=${MONGODB_USER}"
    MONGODUMP_CMD="${MONGODUMP_CMD} --password=${MONGODB_PASSWORD}"
    MONGODUMP_CMD="${MONGODUMP_CMD} --authenticationDatabase=${MONGODB_AUTH_DB:-admin}"
fi

# Add archive and compression
MONGODUMP_CMD="${MONGODUMP_CMD} --archive=${BACKUP_PATH}"
MONGODUMP_CMD="${MONGODUMP_CMD} --gzip"

# Execute backup
echo ""
echo "Executing MongoDB backup..."
echo "Command: mongodump --host=${MONGODB_HOST} --port=${MONGODB_PORT} [auth options] --archive=${BACKUP_PATH} --gzip"
echo ""

if ! eval "${MONGODUMP_CMD}"; then
    echo "ERROR: mongodump failed"
    exit 1
fi

# Verify backup was created
if [ ! -f "${BACKUP_PATH}" ]; then
    echo "ERROR: Backup file was not created"
    exit 1
fi

echo ""
echo "Backup created successfully:"
ls -lh "${BACKUP_PATH}"
echo ""

# Build S3 path
S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}${BACKUP_FILE}"

echo "Uploading backup to S3..."
echo "Destination: ${S3_PATH}"
echo ""

# Upload to S3
if ! aws s3 cp ${AWS_ARGS} "${BACKUP_PATH}" "${S3_PATH}"; then
    echo "ERROR: Failed to upload backup to S3"
    exit 1
fi

echo ""
echo "Backup uploaded successfully!"
echo "S3 Path: ${S3_PATH}"
echo ""

# Cleanup local backup file
echo "Cleaning up local backup file..."
rm -f "${BACKUP_PATH}"
echo "Local backup file removed"
echo ""

echo "=========================================="
echo "Backup completed successfully!"
echo "Completed at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=========================================="

# Optional: List recent backups in S3
echo ""
echo "Recent backups in S3:"
aws s3 ls ${AWS_ARGS} "s3://${S3_BUCKET}/${S3_PREFIX}" | tail -10 || echo "Could not list S3 contents"
echo ""

exit 0
