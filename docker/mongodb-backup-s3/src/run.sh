#!/bin/bash
#
# Entrypoint script for MongoDB backup/restore container
# Dispatches to backup.sh or restore.sh based on MODE environment variable
#

set -e

echo "=========================================="
echo "MongoDB Backup/Restore Container"
echo "=========================================="
echo "Version: 1.0.0"
echo "Started at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Determine mode
MODE="${MODE:-backup}"

case "$MODE" in
    backup)
        echo "Mode: BACKUP"
        echo "=========================================="
        echo ""
        exec /usr/local/bin/backup.sh
        ;;
    restore)
        echo "Mode: RESTORE"
        echo "=========================================="
        echo ""
        exec /usr/local/bin/restore.sh
        ;;
    *)
        echo "ERROR: Invalid MODE='$MODE'"
        echo ""
        echo "Valid modes:"
        echo "  backup  - Backup MongoDB to S3 (default)"
        echo "  restore - Restore MongoDB from S3"
        echo ""
        echo "Usage:"
        echo "  Set MODE environment variable to 'backup' or 'restore'"
        echo ""
        exit 1
        ;;
esac
