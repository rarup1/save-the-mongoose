# Makefile Guide

This guide provides detailed documentation for all Makefile targets in the Save the Mongoose project.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Cluster Management](#cluster-management)
- [MinIO (Local S3)](#minio-local-s3)
- [Chart Development](#chart-development)
- [Deployment](#deployment)
- [Status and Monitoring](#status-and-monitoring)
- [Database Operations](#database-operations)
- [Replication Operations](#replication-operations)
- [Backup Operations](#backup-operations)
- [Testing](#testing)
- [Common Workflows](#common-workflows)

## Quick Reference

```bash
make help              # Show all available targets
make deploy            # Deploy MongoDB standalone
make deploy-replication # Deploy with replica set
make status            # Check deployment status
make connect           # Connect to MongoDB
make clean             # Clean up everything
```

## Cluster Management

### `make minikube-start`
Start a local minikube cluster for development.

**Configuration:**
- Profile: `minikube` (customizable via `MINIKUBE_PROFILE`)
- Memory: 4096 MB
- CPUs: 2
- Driver: `podman` (change to `docker` if needed)

**Usage:**
```bash
make minikube-start
```

**Customize:**
```bash
make minikube-start MINIKUBE_DRIVER=docker MINIKUBE_MEMORY=8192
```

### `make minikube-stop`
Stop the minikube cluster without deleting it.

**Usage:**
```bash
make minikube-stop
```

### `make minikube-delete`
Delete the minikube cluster completely.

**Usage:**
```bash
make minikube-delete
```

**Warning:** This will delete all data in the cluster.

### `make minikube-status`
Show the current status of the minikube cluster.

**Usage:**
```bash
make minikube-status
```

## MinIO (Local S3)

MinIO provides S3-compatible storage for testing backups locally.

### `make minio-start`
Deploy MinIO in the cluster.

**Default Credentials:**
- Access Key: `minioadmin`
- Secret Key: `minioadmin`

**Ports:**
- API: 9000
- Console: 9001

**Usage:**
```bash
make minio-start

# Access console
kubectl port-forward -n default pod/minio 9001:9001
# Visit http://localhost:9001
```

### `make minio-stop`
Stop MinIO pod (keeps the service).

**Usage:**
```bash
make minio-stop
```

### `make minio-remove`
Remove MinIO completely (pod and service).

**Usage:**
```bash
make minio-remove
```

### `make minio-status`
Show MinIO pod and service status.

**Usage:**
```bash
make minio-status
```

### `make minio-logs`
Follow MinIO logs.

**Usage:**
```bash
make minio-logs
```

## Chart Development

### `make lint`
Lint the Helm chart for syntax and best practices.

**Usage:**
```bash
make lint
```

**What it checks:**
- Valid YAML syntax
- Chart.yaml completeness
- Template rendering
- Values schema validation

### `make package`
Package the chart into a `.tgz` archive (runs lint first).

**Usage:**
```bash
make package
```

**Output:** `save-the-mongoose-<version>.tgz`

### `make template`
Render chart templates locally with default values.

**Usage:**
```bash
make template
```

**Use case:** Preview generated Kubernetes manifests before installation.

### `make template-replication`
Render templates with replication enabled.

**Usage:**
```bash
make template-replication
```

**Use case:** Preview replica set configuration.

### `make template-backup`
Render templates with backup configuration.

**Usage:**
```bash
make template-backup
```

**Use case:** Preview backup CronJob and related resources.

## Deployment

### `make deploy`
Deploy MongoDB in standalone mode.

**Usage:**
```bash
make deploy
```

**What it does:**
- Installs the chart with release name `my-mongodb`
- Creates namespace if it doesn't exist
- Waits for pods to be ready

**Customize:**
```bash
make deploy RELEASE_NAME=prod-mongodb NAMESPACE=production
```

### `make deploy-replication`
Deploy MongoDB with replica set (3 members).

**Usage:**
```bash
make deploy-replication
```

**What it deploys:**
- 1 primary (pod-0)
- 2 secondaries (pod-1, pod-2)
- Primary service
- Read-only service
- Headless service

### `make deploy-with-backup`
Deploy with replica set AND S3 backups (starts MinIO first).

**Usage:**
```bash
make deploy-with-backup
```

**What it does:**
1. Starts MinIO for local S3 storage
2. Waits 5 seconds for MinIO to be ready
3. Deploys MongoDB with replication and backup enabled

### `make upgrade`
Upgrade an existing deployment.

**Usage:**
```bash
# Make changes to values or chart
make upgrade
```

**Use case:** Apply configuration changes to running deployment.

### `make uninstall`
Uninstall the Helm release.

**Usage:**
```bash
make uninstall
```

**Note:** PersistentVolumeClaims may remain. Delete manually if needed.

### `make clean`
Complete cleanup (uninstall + remove MinIO).

**Usage:**
```bash
make clean
```

## Status and Monitoring

### `make status`
Show comprehensive deployment status.

**Usage:**
```bash
make status
```

**Output:**
- Helm release status
- Pod list with current state
- Services
- Secrets

### `make watch`
Watch pod status in real-time.

**Usage:**
```bash
make watch
```

**Use case:** Monitor deployment progress or troubleshoot issues.

### `make describe-pod`
Show detailed information about the primary pod (pod-0).

**Usage:**
```bash
make describe-pod
```

**Output:**
- Pod events
- Container status
- Volume mounts
- Resource usage

### `make logs`
Show logs from the primary pod.

**Usage:**
```bash
make logs
```

### `make logs-follow`
Follow logs from the primary pod in real-time.

**Usage:**
```bash
make logs-follow
```

**Use case:** Monitor MongoDB activity or troubleshoot issues.

### `make logs-replica`
Show logs from the first replica (pod-1).

**Usage:**
```bash
make logs-replica
```

## Database Operations

### `make get-password`
Retrieve the MongoDB root password.

**Usage:**
```bash
make get-password
```

**Output:** Decrypted root password from Kubernetes secret.

### `make shell`
Open a bash shell in the primary pod.

**Usage:**
```bash
make shell
```

**Use case:** Manual administration, debugging, file inspection.

### `make connect`
Connect to MongoDB via mongosh (authenticated).

**Usage:**
```bash
make connect
```

**What it does:**
- Retrieves root password from secret
- Opens mongosh session as admin user
- Connects to primary pod

**Example commands in mongosh:**
```javascript
// Show databases
show dbs

// Create a database
use myapp

// Create a collection
db.users.insertOne({name: "Alice", email: "alice@example.com"})

// Query
db.users.find()
```

### `make port-forward`
Forward MongoDB port to localhost.

**Usage:**
```bash
make port-forward
```

**Access:** `mongodb://localhost:27017`

**Use case:** Connect from local tools (MongoDB Compass, mongosh, application).

## Replication Operations

### `make check-replication`
Check replica set status and health.

**Usage:**
```bash
make check-replication
```

**Output:**
- Replica set name and configuration
- Member states (PRIMARY, SECONDARY, ARBITER)
- Health status
- Oplog information
- Sync status

**Example output:**
```json
{
  "set": "rs0",
  "members": [
    {
      "_id": 0,
      "name": "my-mongodb-save-the-mongoose-0...:27017",
      "stateStr": "PRIMARY",
      "health": 1
    },
    {
      "_id": 1,
      "name": "my-mongodb-save-the-mongoose-1...:27017",
      "stateStr": "SECONDARY",
      "health": 1
    }
  ]
}
```

## Backup Operations

### `make trigger-backup`
Manually trigger a backup job (creates a Job from the CronJob).

**Usage:**
```bash
make trigger-backup
```

**What it does:**
- Creates a one-time job from the backup CronJob
- Job name includes timestamp: `manual-backup-1234567890`

**Use case:**
- Test backup configuration
- Create backup before risky operations
- Ad-hoc backups outside schedule

### `make check-backups`
Show status of all backup jobs.

**Usage:**
```bash
make check-backups
```

**Output:**
- Job name
- Completions
- Duration
- Age

### `make backup-logs`
Show logs from the most recent backup job.

**Usage:**
```bash
make backup-logs
```

**What it shows:**
- mongodump output
- S3 upload progress
- Backup file size
- Success/failure status

## Testing

### `make test`
Run Helm tests on deployed release.

**Usage:**
```bash
make test
```

**What it tests:**
- Connection to primary MongoDB
- Authentication (if enabled)
- Basic database operations

### `make quick-test`
Deploy and run tests (fast validation).

**Usage:**
```bash
make quick-test
```

**Steps:**
1. Deploy chart (standalone)
2. Run Helm tests
3. Report results

### `make full-test`
Complete test suite (lint + deploy with replication + test).

**Usage:**
```bash
make full-test
```

**Steps:**
1. Lint chart
2. Deploy with replication
3. Run Helm tests

### `make reset`
Clean up and redeploy (fresh start).

**Usage:**
```bash
make reset
```

**Steps:**
1. Uninstall existing release
2. Remove MinIO
3. Deploy fresh installation

**Use case:** Start over with clean state.

## Common Workflows

### Local Development Setup

```bash
# 1. Start cluster
make minikube-start

# 2. Deploy with all features
make deploy-with-backup

# 3. Check status
make status

# 4. Monitor logs
make logs-follow
```

### Testing Configuration Changes

```bash
# 1. Make changes to values or templates

# 2. Lint
make lint

# 3. Render templates to preview
make template-replication

# 4. Upgrade deployment
make upgrade

# 5. Check status
make status

# 6. Run tests
make test
```

### Backup Testing Workflow

```bash
# 1. Deploy with backup enabled
make deploy-with-backup

# 2. Wait for deployment
make watch

# 3. Trigger manual backup
make trigger-backup

# 4. Monitor backup
make backup-logs

# 5. Check backup job status
make check-backups

# 6. Access MinIO console to verify backup file
kubectl port-forward pod/minio 9001:9001
# Open http://localhost:9001
```

### Replica Set Testing

```bash
# 1. Deploy replica set
make deploy-replication

# 2. Check replica status
make check-replication

# 3. Connect and test
make connect
# In mongosh:
# > db.test.insertOne({msg: "hello"})
# > db.test.find()

# 4. Test failover (kill primary)
kubectl delete pod my-mongodb-save-the-mongoose-0

# 5. Watch election
make check-replication

# 6. Verify data after failover
make connect
# > db.test.find()
```

### Complete Cleanup

```bash
# Remove everything
make clean

# Or step by step:
make uninstall      # Remove Helm release
make minio-remove   # Remove MinIO

# Delete PVCs manually if needed
kubectl delete pvc -l app.kubernetes.io/instance=my-mongodb
```

## Customization

### Change Release Name

```bash
make deploy RELEASE_NAME=prod-db
make status RELEASE_NAME=prod-db
make uninstall RELEASE_NAME=prod-db
```

### Change Namespace

```bash
make deploy NAMESPACE=production
make status NAMESPACE=production
make connect NAMESPACE=production
```

### Change Both

```bash
export RELEASE_NAME=prod-db
export NAMESPACE=production

make deploy
make status
make connect
```

## Troubleshooting

### Pods Not Starting

```bash
# Check events
make describe-pod

# Check logs
make logs

# Check all pod events
kubectl get events -n default --sort-by='.lastTimestamp'
```

### Connection Issues

```bash
# Test connection
make test

# Check services
kubectl get svc -l app.kubernetes.io/instance=my-mongodb

# Port forward and test locally
make port-forward
mongosh mongodb://localhost:27017
```

### Backup Failures

```bash
# Check CronJob
kubectl get cronjob my-mongodb-save-the-mongoose-backup -o yaml

# Trigger manual backup
make trigger-backup

# Watch logs
make backup-logs

# Verify S3 credentials
kubectl get secret my-mongodb-save-the-mongoose-s3 -o yaml
```

## Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `CHART_NAME` | `save-the-mongoose` | Helm chart name |
| `RELEASE_NAME` | `my-mongodb` | Helm release name |
| `NAMESPACE` | `default` | Kubernetes namespace |
| `MINIKUBE_PROFILE` | `minikube` | Minikube profile name |
| `MINIKUBE_MEMORY` | `4096` | Memory in MB |
| `MINIKUBE_CPUS` | `2` | Number of CPUs |
| `MINIKUBE_DRIVER` | `podman` | Container runtime |

Override any variable:
```bash
make deploy RELEASE_NAME=custom NAMESPACE=prod
```
