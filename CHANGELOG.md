# Changelog

All notable changes to the Save the Mongoose Helm chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-10-28

### Added
- Initial release of Save the Mongoose Helm chart
- MongoDB 8.0 support with compatibility for versions 4.4-8.x
- Replica set support with configurable member count and automatic initialization on deployment
- Automated S3 backup functionality via CronJob with custom Docker image
- Custom Docker image (`mongodb-backup-s3`) for backup and restore operations with multi-architecture support (linux/amd64, linux/arm64)
- Three service types: headless, primary, and read-only
- Authentication enabled by default with auto-generated passwords
- Secret persistence using Kubernetes `lookup` function for auto-generated passwords and replica set keys
- Configurable resource limits and requests
- Persistent storage with configurable size and storage class
- Security contexts for pods and containers
- Liveness and readiness probes for MongoDB
- StatefulSet for stable network identities
- ServiceAccount with image pull secrets support
- Helm tests for connection verification
- Example configuration files (basic, replication, replication-and-backup)
- Comprehensive Makefile for development and operations (50+ targets)
- GitHub Actions workflows:
  - PR validation (lint, template, install tests)
  - Automated releases with chart-releaser
  - Build and push Docker images for MongoDB versions 4.4, 5.0, 6.0, 7.0, and 8.0
- Complete documentation (README, CONTRIBUTING, MAKEFILE_GUIDE, NOTES.txt)
- Comprehensive configuration parameters documentation in README with 78 documented parameters
- MinIO S3-compatible storage support with path-style addressing
- Environment variable validation in backup/restore scripts with clear error messages
- Automatic sysctl configuration for MongoDB optimization (vm.max_map_count)
- Chart-releaser configuration for automated Helm releases
- GitHub Pages integration for Helm repository hosting

### Changed
- Replica set initialization now uses a custom MongoDB startup script instead of lifecycle hooks
- Backup image simplified - no longer requires inline bash scripts in CronJob
- S3 backup prefix now defaults to `release=<name>/namespace=<ns>/` pattern
- Backup image published to DockerHub at `rarup1/mongodb-backup-s3`
- Backup image pull policy changed from `Never` to `IfNotPresent`
- Backup image tag automatically computed from MongoDB version (e.g., 8.0.3 → 8.0)

### Fixed
- Replica set initialization with authentication enabled (chicken-and-egg problem resolved)
- MongoDB startup warnings for vm.max_map_count
- S3 path-style addressing for MinIO compatibility
- Backup failures with `(NotPrimaryOrSecondary)` error by ensuring replica set is initialized
- Auto-generated passwords now persist across helm upgrades to prevent authentication failures with existing PVCs
- Replica set keys now persist across helm upgrades to maintain cluster security consistency
- Docker image builds for older MongoDB versions (4.4, 5.0) with expired GPG keys
- MinIO Makefile target now uses external manifest file with namespace substitution

[Unreleased]: https://github.com/rarup1/save-the-mongoose/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/rarup1/save-the-mongoose/releases/tag/v0.1.0
