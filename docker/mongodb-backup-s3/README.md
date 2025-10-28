# MongoDB Backup S3 Docker Image

Docker image for backing up and restoring MongoDB databases to S3-compatible storage.

## Overview

This image provides a simple and reliable way to backup MongoDB databases to S3-compatible storage services (AWS S3, MinIO, etc.). It includes both backup and restore functionality with comprehensive error handling and validation.

## Supported Tags

- `8.0`, `latest` - MongoDB 8.0
- `7.0` - MongoDB 7.0
- `6.0` - MongoDB 6.0
- `5.0` - MongoDB 5.0
- `4.4` - MongoDB 4.4

All images support both `linux/amd64` and `linux/arm64` architectures.

## Features

- **Backup to S3**: Automated backups using `mongodump` with gzip compression
- **Restore from S3**: Easy restoration using `mongorestore`
- **Environment Validation**: Comprehensive validation with clear error messages
- **S3 Compatibility**: Works with AWS S3, MinIO, and other S3-compatible services
- **Path-Style Addressing**: Support for MinIO and S3-compatible services
- **Multi-Architecture**: Supports both `linux/amd64` and `linux/arm64`
- **Security**: Runs as non-root user (mongodb:999)

## Quick Start

### Backup Example

```bash
docker run --rm \
  -e MODE=backup \
  -e MONGODB_HOST=mongodb.example.com \
  -e MONGODB_PORT=27017 \
  -e MONGODB_USER=admin \
  -e MONGODB_PASSWORD=secret \
  -e S3_ENDPOINT=s3.amazonaws.com \
  -e S3_BUCKET=my-backups \
  -e S3_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE \
  -e S3_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  -e S3_PREFIX=mongodb/production/ \
  rarup1/mongodb-backup-s3:8.0
```

### Restore Example

```bash
docker run --rm -it \
  -e MODE=restore \
  -e MONGODB_HOST=mongodb.example.com \
  -e MONGODB_PORT=27017 \
  -e MONGODB_USER=admin \
  -e MONGODB_PASSWORD=secret \
  -e S3_ENDPOINT=s3.amazonaws.com \
  -e S3_BUCKET=my-backups \
  -e S3_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE \
  -e S3_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  -e BACKUP_FILE=mongodb/production/backup-2024-01-15-020000.archive.gz \
  -e DROP_BEFORE_RESTORE=false \
  rarup1/mongodb-backup-s3:8.0
```

## Environment Variables

### Required for Backup

| Variable | Description |
|----------|-------------|
| `MODE` | Operation mode: `backup` or `restore` (default: `backup`) |
| `MONGODB_HOST` | MongoDB hostname or IP |
| `MONGODB_PORT` | MongoDB port (default: 27017) |
| `S3_ENDPOINT` | S3 endpoint (e.g., `s3.amazonaws.com` or `minio.example.com:9000`) |
| `S3_BUCKET` | S3 bucket name |
| `S3_ACCESS_KEY_ID` | S3 access key ID |
| `S3_SECRET_ACCESS_KEY` | S3 secret access key |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `MONGODB_USER` | MongoDB username | - |
| `MONGODB_PASSWORD` | MongoDB password | - |
| `MONGODB_AUTH_DB` | Authentication database | `admin` |
| `S3_PREFIX` | S3 key prefix | `""` |
| `S3_REGION` | S3 region | `us-east-1` |
| `S3_FORCE_PATH_STYLE` | Force path-style addressing (for MinIO) | `false` |
| `S3_USE_SSL` | Use SSL for S3 connection | `true` |
| `BACKUP_FILE` | S3 key for restore (required for restore mode) | - |
| `DROP_BEFORE_RESTORE` | Drop collections before restore | `false` |
| `SKIP_CONFIRM` | Skip confirmation prompt for restore | `false` |

## Kubernetes CronJob Example

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mongodb-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: rarup1/mongodb-backup-s3:8.0
            env:
            - name: MODE
              value: "backup"
            - name: MONGODB_HOST
              value: "mongodb-primary.default.svc.cluster.local"
            - name: MONGODB_PORT
              value: "27017"
            - name: MONGODB_USER
              valueFrom:
                secretKeyRef:
                  name: mongodb-credentials
                  key: username
            - name: MONGODB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mongodb-credentials
                  key: password
            - name: S3_ENDPOINT
              value: "s3.amazonaws.com"
            - name: S3_BUCKET
              value: "my-mongodb-backups"
            - name: S3_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: s3-credentials
                  key: access-key-id
            - name: S3_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: s3-credentials
                  key: secret-access-key
          restartPolicy: OnFailure
```

## MinIO Configuration

For MinIO or other S3-compatible services, set `S3_FORCE_PATH_STYLE=true`:

```bash
docker run --rm \
  -e MODE=backup \
  -e MONGODB_HOST=mongodb \
  -e S3_ENDPOINT=minio.example.com:9000 \
  -e S3_BUCKET=backups \
  -e S3_FORCE_PATH_STYLE=true \
  -e S3_USE_SSL=false \
  -e S3_ACCESS_KEY_ID=minioadmin \
  -e S3_SECRET_ACCESS_KEY=minioadmin \
  rarup1/mongodb-backup-s3:8.0
```

## Backup File Naming

Backups are stored with the following naming convention:

```
<S3_PREFIX>backup-YYYY-MM-DD-HHMMSS.archive.gz
```

Example: `mongodb/production/backup-2024-01-15-020000.archive.gz`

## Using with Save the Mongoose Helm Chart

This image is designed to work seamlessly with the [Save the Mongoose Helm Chart](https://github.com/rarup1/save-the-mongoose):

```yaml
backup:
  enabled: true
  image:
    repository: rarup1/mongodb-backup-s3
    tag: "8.0"
    pullPolicy: IfNotPresent
  schedule: "0 2 * * *"
  s3:
    endpoint: s3.amazonaws.com
    bucket: mongodb-backups
    region: us-east-1
    accessKeyId: AKIAIOSFODNN7EXAMPLE
    secretAccessKey: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

## Building the Image

To build the image locally:

```bash
# Build for MongoDB 8.0
docker build --build-arg MONGODB_VERSION=8.0 -t rarup1/mongodb-backup-s3:8.0 .

# Build for MongoDB 7.0
docker build --build-arg MONGODB_VERSION=7.0 -t rarup1/mongodb-backup-s3:7.0 .

# Multi-architecture build
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg MONGODB_VERSION=8.0 \
  -t rarup1/mongodb-backup-s3:8.0 \
  --push .
```

## Scripts

The image contains four main scripts:

- `/usr/local/bin/run.sh` - Entrypoint dispatcher
- `/usr/local/bin/env.sh` - Environment validation
- `/usr/local/bin/backup.sh` - Backup functionality
- `/usr/local/bin/restore.sh` - Restore functionality

## Exit Codes

- `0` - Success
- `1` - Error (validation failure, backup failure, restore failure)

## Source Code

Source code and documentation: [https://github.com/rarup1/save-the-mongoose](https://github.com/rarup1/save-the-mongoose)

## License

MIT License - See repository for details.

## Maintainer

rarup1
