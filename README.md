# Save the Mongoose

A production-ready Helm chart for deploying MongoDB with replica set support and S3 backup capabilities.

## Features

- **MongoDB 8.0** with support for versions 4.4-8.x
- **Replica Set Support** for high availability with automatic initialization
- **Automated S3 Backups** with custom Docker image and configurable schedules
- **No Custom Resource Definitions (CRDs)** - uses native Kubernetes resources only
- **Flexible Service Configuration** - separate services for primary and read-only workloads
- **Security-First** - authentication enabled by default, configurable security contexts
- **Production Ready** - resource limits, health checks, and persistent storage
- **Easy Development** - comprehensive Makefile with 50+ targets for local testing

## Quick Start

### Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PV provisioner support in the underlying infrastructure (for persistence)

### Basic Installation

```bash
# Add the Helm repository
helm repo add save-the-mongoose https://rarup1.github.io/save-the-mongoose
helm repo update

# Install MongoDB (standalone)
helm install my-mongodb save-the-mongoose/save-the-mongoose

# Get the root password
kubectl get secret my-mongodb-save-the-mongoose-mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d
```

### Installation with Replica Sets

```bash
helm install my-mongodb save-the-mongoose/save-the-mongoose \
  --set replication.enabled=true \
  --set replication.replicaCount=3
```

### Installation with Replica Set and S3 Backups

```bash
helm install my-mongodb save-the-mongoose/save-the-mongoose \
  --set backup.enabled=true \
  --set backup.s3.endpoint="s3.amazonaws.com" \
  --set backup.s3.bucket="my-mongodb-backups" \
  --set backup.s3.accessKeyId="YOUR_ACCESS_KEY" \
  --set backup.s3.secretAccessKey="YOUR_SECRET_KEY" \
  --set replication.enabled=true \
  --set replication.replicaCount=3
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mongodb.image.tag` | MongoDB version | `8.0` |
| `mongodb.auth.enabled` | Enable authentication | `true` |
| `mongodb.auth.rootPassword` | Root password (auto-generated if not set) | `""` |
| `mongodb.persistence.size` | Storage size | `10Gi` |
| `replication.enabled` | Enable replica set | `false` |
| `replication.replicaCount` | Number of replica members | `1` |
| `replication.replSetName` | Replica set name | `rs0` |
| `backup.enabled` | Enable S3 backups | `false` |
| `backup.schedule` | Backup schedule (cron) | `"0 2 * * *"` |
| `backup.s3.bucket` | S3 bucket name | `""` |
| `backup.s3.endpoint` | S3 endpoint | `""` |

For a comprehensive list of all available parameters, see the [Configuration Parameters](#configuration-parameters) section below.

### Password and Secret Persistence

The chart automatically generates and persists passwords and security keys when not explicitly set:

- **Root Password**: If `mongodb.auth.rootPassword` is empty, a random 16-character password is generated on first install and automatically persisted in the Kubernetes secret. Subsequent `helm upgrade` operations will reuse the existing password from the secret, preventing authentication failures with existing PVCs.

- **Replica Set Key**: When replication is enabled, a 756-character replica set keyfile is automatically generated and persisted. This ensures consistent cluster security across upgrades.

This persistence is achieved using the Kubernetes `lookup` function to check for existing secrets before generating new values.

**Note**: The `lookup` function only works during actual deployments to a Kubernetes cluster. When using `helm template` for testing, new random values will be generated each time since no cluster secrets exist.

### Example Values Files

The `examples/` directory contains pre-configured values files:

- **[basic.values.yaml](examples/basic.values.yaml)** - Standalone MongoDB for development
- **[replication.values.yaml](examples/replication.values.yaml)** - Replica set with 3 members
- **[replication-and-backup.values.yaml](examples/replication-and-backup.values.yaml)** - Replica set with S3 backups

## Architecture

### Replica Set Architecture

When replication is enabled, the chart deploys a MongoDB replica set with automatic initialization:

- **Pod-0**: Primary (read-write operations)
- **Pod-1, Pod-2, ...**: Secondaries (read operations, automatic failover)

The chart includes a custom startup script that handles the replica set initialization chicken-and-egg problem by detecting first boot and starting MongoDB without keyFile for initialization, then using keyFile for security on subsequent boots.

### Services

The chart creates three services:

1. **Headless Service** (`<release>-save-the-mongoose-headless`)
   - Used for DNS discovery and StatefulSet pod addressing
   - Enables replica set members to communicate

2. **Primary Service** (`<release>-save-the-mongoose-primary`)
   - Routes to pod-0 (primary)
   - Use for read-write operations

3. **Read-Only Service** (`<release>-save-the-mongoose-readonly`) _(optional)_
   - Routes to secondary replicas
   - Use for read-only operations to reduce primary load

### Backup Strategy

The chart uses a custom Docker image (`mongodb-backup-s3`) with modular scripts:

- **backup.sh** - Performs mongodump and uploads to S3
- **restore.sh** - Downloads from S3 and restores to MongoDB
- **env.sh** - Validates environment variables with clear error messages
- **run.sh** - Entrypoint dispatcher based on MODE variable

A CronJob executes scheduled backups:

1. Connects to the primary MongoDB instance
2. Creates a compressed archive using `mongodump`
3. Uploads to S3-compatible storage (AWS S3, MinIO, etc.)
4. Cleans up local backup files

**Features**:
- Support for MinIO and AWS S3 with path-style addressing
- Comprehensive environment validation
- Restore capability included
- Configurable retention (set at bucket level)

## Operations

### Connecting to MongoDB

```bash
# Get the root password
export MONGODB_ROOT_PASSWORD=$(kubectl get secret my-mongodb-save-the-mongoose-mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d)

# Port-forward to access locally
kubectl port-forward svc/my-mongodb-save-the-mongoose-primary 27017:27017

# Connect via mongosh
mongosh mongodb://admin:${MONGODB_ROOT_PASSWORD}@localhost:27017/admin
```

### Checking Replica Set Status

```bash
kubectl exec -it my-mongodb-save-the-mongoose-0 -- mongosh \
  --username admin \
  --password <password> \
  --authenticationDatabase admin \
  --eval "rs.status()"
```

### Manual Backup

```bash
# Trigger a manual backup
kubectl create job --from=cronjob/my-mongodb-save-the-mongoose-backup manual-backup-$(date +%s)

# Check backup job status
kubectl get jobs -l component=backup

# View backup logs
kubectl logs -l component=backup --tail=100
```

### Scaling Replica Set

```bash
# Scale up (add more replicas)
helm upgrade my-mongodb save-the-mongoose/save-the-mongoose \
  --set replication.replicaCount=5 \
  --reuse-values

# Note: Scaling down requires manual intervention to remove members from the replica set
```

## Development

This repository includes a comprehensive Makefile for local development:

```bash
# Start local cluster
make minikube-start

# Start MinIO for S3 testing
make minio-start

# Deploy MongoDB with replication and backups
make deploy-with-backup

# Check status
make status

# Connect to MongoDB
make connect

# Check replica set status
make check-replication

# Trigger manual backup
make trigger-backup

# Run tests
make test

# Cleanup
make clean
```

See [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md) for complete documentation of all 50+ targets.

## Upgrading

### Chart Upgrades

```bash
helm upgrade my-mongodb save-the-mongoose/save-the-mongoose \
  --reuse-values \
  --wait
```

### MongoDB Version Upgrades

1. Check MongoDB upgrade path compatibility
2. Update `mongodb.image.tag` in values
3. Upgrade the release
4. Monitor replica set health

```bash
helm upgrade my-mongodb save-the-mongoose/save-the-mongoose \
  --set mongodb.image.tag=8.0 \
  --reuse-values \
  --wait
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/instance=my-mongodb

# Describe pod for events
kubectl describe pod my-mongodb-save-the-mongoose-0

# Check logs
kubectl logs my-mongodb-save-the-mongoose-0
```

### Replica Set Not Initializing

```bash
# Check initialization logs
kubectl logs my-mongodb-save-the-mongoose-0

# Verify all pods are ready
kubectl get pods -l app.kubernetes.io/instance=my-mongodb -w

# Manually check replica set status
kubectl exec -it my-mongodb-save-the-mongoose-0 -- mongosh --eval "rs.status()"
```

### Backup Failures

```bash
# Check CronJob configuration
kubectl get cronjob my-mongodb-save-the-mongoose-backup -o yaml

# View recent backup job logs
kubectl logs -l component=backup --tail=200

# Verify S3 credentials
kubectl get secret my-mongodb-save-the-mongoose-s3 -o yaml
```

## Security Considerations

1. **Authentication**: Always enable authentication in production (`mongodb.auth.enabled=true`)
2. **Passwords**: Use strong, randomly-generated passwords
3. **Secrets**: Use `existingSecret` for production deployments
4. **Network Policies**: Consider implementing NetworkPolicies to restrict access
5. **Encryption**: Enable encryption at rest at the storage layer
6. **S3 Security**: Use IAM roles or IRSA instead of access keys when possible

## Supported MongoDB Versions

| Version | Status | Notes |
|---------|--------|-------|
| 8.0 | ✅ Tested | Default version |
| 7.0 | ✅ Compatible | |
| 6.0 | ✅ Compatible | |
| 5.0 | ✅ Compatible | |
| 4.4 | ✅ Compatible | Minimum recommended |
| 4.2 | ⚠️ EOL | Not recommended |

## Configuration Parameters

This section provides a comprehensive list of all configurable parameters in the `values.yaml` file.

### MongoDB Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mongodb.image.repository` | MongoDB Docker image repository | `mongo` |
| `mongodb.image.tag` | MongoDB image tag (version) | `8.0` |
| `mongodb.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `mongodb.auth.enabled` | Enable MongoDB authentication | `true` |
| `mongodb.auth.rootUser` | Root username | `admin` |
| `mongodb.auth.rootPassword` | Root password (auto-generated if empty) | `""` |
| `mongodb.auth.existingSecret` | Existing secret for MongoDB credentials | `""` |
| `mongodb.resources.limits.cpu` | CPU limit | `1000m` |
| `mongodb.resources.limits.memory` | Memory limit | `2Gi` |
| `mongodb.resources.requests.cpu` | CPU request | `500m` |
| `mongodb.resources.requests.memory` | Memory request | `1Gi` |
| `mongodb.persistence.enabled` | Enable persistent storage | `true` |
| `mongodb.persistence.storageClass` | Storage class name | `""` |
| `mongodb.persistence.accessMode` | Access mode for PVC | `ReadWriteOnce` |
| `mongodb.persistence.size` | Storage size | `10Gi` |
| `mongodb.config.storageEngine` | Storage engine | `wiredTiger` |
| `mongodb.config.oplogSizeMB` | Oplog size in MB | `1024` |
| `mongodb.config.maxIncomingConnections` | Maximum incoming connections | `100` |
| `mongodb.config.verbosity` | Logging verbosity (0-5) | `0` |
| `mongodb.config.profilingLevel` | Profiling level (0=off, 1=slow, 2=all) | `0` |
| `mongodb.config.slowOpThresholdMs` | Slow operation threshold in ms | `100` |
| `mongodb.livenessProbe.enabled` | Enable liveness probe | `true` |
| `mongodb.livenessProbe.initialDelaySeconds` | Initial delay for liveness probe | `30` |
| `mongodb.livenessProbe.periodSeconds` | Period for liveness probe | `10` |
| `mongodb.livenessProbe.timeoutSeconds` | Timeout for liveness probe | `5` |
| `mongodb.livenessProbe.successThreshold` | Success threshold for liveness probe | `1` |
| `mongodb.livenessProbe.failureThreshold` | Failure threshold for liveness probe | `6` |
| `mongodb.readinessProbe.enabled` | Enable readiness probe | `true` |
| `mongodb.readinessProbe.initialDelaySeconds` | Initial delay for readiness probe | `5` |
| `mongodb.readinessProbe.periodSeconds` | Period for readiness probe | `10` |
| `mongodb.readinessProbe.timeoutSeconds` | Timeout for readiness probe | `5` |
| `mongodb.readinessProbe.successThreshold` | Success threshold for readiness probe | `1` |
| `mongodb.readinessProbe.failureThreshold` | Failure threshold for readiness probe | `3` |

### Replication Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replication.enabled` | Enable MongoDB replica set | `false` |
| `replication.replSetName` | Replica set name | `rs0` |
| `replication.replicaCount` | Number of replica members (includes primary) | `1` |
| `replication.readPreference` | Read preference (primary, primaryPreferred, secondary, secondaryPreferred, nearest) | `primaryPreferred` |
| `replication.arbiter.enabled` | Enable arbiter for tie-breaking | `false` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | MongoDB service port | `27017` |
| `service.annotations` | Service annotations | `{}` |
| `service.labels` | Service labels | `{}` |
| `service.primary.enabled` | Enable primary service | `true` |
| `service.primary.type` | Primary service type | `ClusterIP` |
| `service.primary.port` | Primary service port | `27017` |
| `service.readonly.enabled` | Enable read-only service | `false` |
| `service.readonly.type` | Read-only service type | `ClusterIP` |
| `service.readonly.port` | Read-only service port | `27017` |

### Backup Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backup.enabled` | Enable scheduled S3 backups | `false` |
| `backup.schedule` | Backup schedule (cron format) | `"0 2 * * *"` |
| `backup.suspend` | Suspend the CronJob | `false` |
| `backup.successfulJobsHistoryLimit` | Successful jobs to retain | `3` |
| `backup.failedJobsHistoryLimit` | Failed jobs to retain | `1` |
| `backup.ttlSecondsAfterFinished` | TTL for finished jobs in seconds | `300` |
| `backup.image.repository` | Backup image repository | `rarup1/mongodb-backup-s3` |
| `backup.image.tag` | Backup image tag (MongoDB version) | `8.0` |
| `backup.image.pullPolicy` | Backup image pull policy | `IfNotPresent` |
| `backup.s3.endpoint` | S3 endpoint | `""` |
| `backup.s3.bucket` | S3 bucket name | `""` |
| `backup.s3.region` | S3 region | `us-east-1` |
| `backup.s3.prefix` | S3 path prefix | `""` (auto-generated) |
| `backup.s3.accessKeyId` | S3 access key ID | `""` |
| `backup.s3.secretAccessKey` | S3 secret access key | `""` |
| `backup.s3.existingSecret` | Existing secret for S3 credentials | `""` |
| `backup.s3.forcePathStyle` | Force path-style S3 addressing (for MinIO) | `false` |
| `backup.s3.useSSL` | Use SSL for S3 connection | `true` |
| `backup.resources.limits.cpu` | CPU limit for backup jobs | `500m` |
| `backup.resources.limits.memory` | Memory limit for backup jobs | `512Mi` |
| `backup.resources.requests.cpu` | CPU request for backup jobs | `100m` |
| `backup.resources.requests.memory` | Memory request for backup jobs | `128Mi` |

### Service Account Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create a service account | `true` |
| `serviceAccount.annotations` | Service account annotations | `{}` |
| `serviceAccount.name` | Service account name | `""` (auto-generated) |
| `serviceAccount.imagePullSecrets` | Image pull secrets | `[]` |

### Security Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podSecurityContext.fsGroup` | FSGroup for pod security context | `999` |
| `securityContext.runAsNonRoot` | Run container as non-root user | `true` |
| `securityContext.runAsUser` | User ID to run container | `999` |

### Pod Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podAnnotations` | Pod annotations | `{}` |
| `podLabels` | Pod labels | `{}` |
| `nodeSelector` | Node selector for pod assignment | `{}` |
| `tolerations` | Tolerations for pod assignment | `[]` |
| `affinity` | Affinity rules for pod assignment | `{}` |

### Advanced Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `initContainers` | Init containers | `[{setup-sysctl}]` |
| `extraVolumes` | Extra volumes to mount | `[]` |
| `extraVolumeMounts` | Extra volume mounts | `[]` |
| `extraEnvVars` | Extra environment variables | `[]` |

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

Inspired by [save-the-elephant](https://github.com/yourusername/save-the-elephant) - a similar Helm chart for PostgreSQL.

## Support

- Report bugs: [GitHub Issues](https://github.com/yourusername/save-the-mongoose/issues)
- Documentation: [MongoDB Manual](https://docs.mongodb.com/manual/)
- Helm Charts: [Artifact Hub](https://artifacthub.io/)
