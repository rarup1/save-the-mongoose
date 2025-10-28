# Changelog

All notable changes to the Save the Mongoose Helm chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Custom Docker image (`mongodb-backup-s3`) for backup and restore operations
- Automatic replica set initialization on deployment using custom startup script
- Support for both standalone and replica set modes
- MinIO S3-compatible storage support with path-style addressing
- Comprehensive backup image with restore capabilities
- Environment variable validation in backup/restore scripts
- Automatic sysctl configuration for MongoDB optimization (vm.max_map_count)
- Secret persistence using Kubernetes `lookup` function for auto-generated passwords and replica set keys
- GitHub Actions workflow to build and push Docker images for MongoDB versions 4.4, 5.0, 6.0, 7.0, and 8.0
- Multi-architecture support (linux/amd64, linux/arm64) for backup Docker images
- Comprehensive configuration parameters documentation in README

### Changed
- Replica set initialization now uses a custom MongoDB startup script instead of lifecycle hooks
- Improved replica set initialization to handle first boot vs. subsequent restarts
- Backup image simplified - no longer requires inline bash scripts in CronJob
- S3 backup prefix now defaults to `release=<name>/namespace=<ns>/` pattern
- Backup image now published to DockerHub at `rarup1/mongodb-backup-s3`
- Default backup image pull policy changed from `Never` to `IfNotPresent`

### Fixed
- Replica set initialization with authentication enabled (chicken-and-egg problem resolved)
- MongoDB startup warnings for vm.max_map_count
- S3 path-style addressing for MinIO compatibility
- Backup failures with `(NotPrimaryOrSecondary)` error by ensuring replica set is initialized
- Auto-generated passwords now persist across helm upgrades to prevent authentication failures with existing PVCs
- Replica set keys now persist across helm upgrades to maintain cluster security consistency

## [0.1.0] - 2025-10-26

### Added
- Initial release of Save the Mongoose Helm chart
- MongoDB 8.0 support with compatibility for versions 4.4-8.x
- Replica set support with configurable member count
- Automated S3 backup functionality via CronJob
- Three service types: headless, primary, and read-only
- Authentication enabled by default with auto-generated passwords
- Configurable resource limits and requests
- Persistent storage with configurable size and storage class
- Security contexts for pods and containers
- Liveness and readiness probes for MongoDB
- StatefulSet for stable network identities
- ServiceAccount with image pull secrets support
- Helm tests for connection verification
- Example configuration files:
  - `basic.values.yaml` - Standalone deployment
  - `replication.values.yaml` - Replica set with 3 members
  - `replication-and-backup.values.yaml` - Replica set with S3 backups
- Comprehensive Makefile for development and operations
- GitHub Actions workflows:
  - PR validation (lint, template, install tests)
  - Automated releases with chart-releaser
- Complete documentation:
  - README with quick start and configuration guide
  - CONTRIBUTING guidelines
  - MAKEFILE_GUIDE for development
  - Detailed NOTES.txt with post-installation instructions

### Features
- **No CRD Dependencies**: Uses only native Kubernetes resources (StatefulSet, Service, ConfigMap, Secret, CronJob)
- **Replica Set Initialization**: Automatic replica set configuration on first deployment
- **Flexible Backup Schedule**: Configurable cron schedule for S3 backups
- **S3 Compatibility**: Works with AWS S3, MinIO, and other S3-compatible services
- **Pod Anti-Affinity**: Optional configuration to spread replicas across nodes
- **Init Containers**: Support for custom initialization containers
- **Extra Volumes**: Extensible volume and volume mount configuration
- **Environment Variables**: Support for custom environment variables

### Configuration Options
- MongoDB image and version selection
- Authentication with root user credentials
- Resource limits and requests
- Persistence with storage class and size
- Replica set configuration (name, count, read preference)
- Service types and ports (primary, read-only, headless)
- Backup configuration (schedule, S3 settings, retention)
- Security contexts (pod and container level)
- Node selector, tolerations, and affinity rules
- Liveness and readiness probe settings
- MongoDB configuration (storage engine, oplog size, connections, etc.)

### Default Settings
- MongoDB version: 8.0
- Authentication: Enabled
- Replication: Disabled (standalone mode)
- Replica count: 1
- Persistence: 10Gi
- Backup schedule: Daily at 2 AM UTC
- Service type: ClusterIP
- Resource limits: 1 CPU, 2Gi memory
- Resource requests: 500m CPU, 1Gi memory

[Unreleased]: https://github.com/yourusername/save-the-mongoose/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/save-the-mongoose/releases/tag/v0.1.0
