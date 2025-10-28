# Makefile for Save the Mongoose - MongoDB Helm Chart
# See MAKEFILE_GUIDE.md for detailed usage instructions

# Variables
CHART_NAME := save-the-mongoose
RELEASE_NAME := my-mongodb
NAMESPACE := default
MINIKUBE_PROFILE := minikube
MINIKUBE_MEMORY := 4096
MINIKUBE_CPUS := 2
MINIKUBE_DRIVER := podman

# Colors for output
COLOR_RESET := \033[0m
COLOR_BOLD := \033[1m
COLOR_GREEN := \033[32m
COLOR_YELLOW := \033[33m
COLOR_BLUE := \033[34m

.PHONY: help
help: ## Show this help message
	@echo "$(COLOR_BOLD)Save the Mongoose - MongoDB Helm Chart$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BOLD)Usage:$(COLOR_RESET)"
	@echo "  make $(COLOR_GREEN)<target>$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BOLD)Available targets:$(COLOR_RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-30s$(COLOR_RESET) %s\n", $$1, $$2}'

# ==============================================================================
# Minikube / Kind Cluster Management
# ==============================================================================

.PHONY: minikube-start
minikube-start: ## Start minikube cluster
	@echo "$(COLOR_BLUE)Starting minikube cluster...$(COLOR_RESET)"
	minikube start --profile=$(MINIKUBE_PROFILE) --memory=$(MINIKUBE_MEMORY) --cpus=$(MINIKUBE_CPUS) --driver=$(MINIKUBE_DRIVER)

.PHONY: minikube-stop
minikube-stop: ## Stop minikube cluster
	@echo "$(COLOR_BLUE)Stopping minikube cluster...$(COLOR_RESET)"
	minikube stop --profile=$(MINIKUBE_PROFILE)

.PHONY: minikube-delete
minikube-delete: ## Delete minikube cluster
	@echo "$(COLOR_YELLOW)Deleting minikube cluster...$(COLOR_RESET)"
	minikube delete --profile=$(MINIKUBE_PROFILE)

.PHONY: minikube-status
minikube-status: ## Show minikube status
	minikube status --profile=$(MINIKUBE_PROFILE)

# ==============================================================================
# MinIO (Local Minikube S3 for testing)
# ==============================================================================

.PHONY: minio-start
minio-start: ## Start MinIO for local S3 testing
	@echo "$(COLOR_BLUE)Starting MinIO...$(COLOR_RESET)"
	@NAMESPACE=$(NAMESPACE) envsubst < examples/minio.yaml | kubectl apply -f -
	@echo "$(COLOR_GREEN)MinIO started. Access console with: kubectl port-forward -n $(NAMESPACE) pod/minio 9001:9001$(COLOR_RESET)"

.PHONY: minio-stop
minio-stop: ## Stop MinIO
	kubectl delete pod minio -n $(NAMESPACE) --ignore-not-found

.PHONY: minio-remove
minio-remove: ## Remove MinIO completely
	kubectl delete pod,service minio -n $(NAMESPACE) --ignore-not-found

.PHONY: minio-status
minio-status: ## Show MinIO status
	kubectl get pod,service minio -n $(NAMESPACE)

.PHONY: minio-logs
minio-logs: ## Show MinIO logs
	kubectl logs -n $(NAMESPACE) minio -f

# ==============================================================================
# Helm Chart Development
# ==============================================================================

.PHONY: lint
lint: ## Lint the Helm chart
	@echo "$(COLOR_BLUE)Linting Helm chart...$(COLOR_RESET)"
	helm lint $(CHART_NAME)

.PHONY: package
package: lint ## Package the Helm chart
	@echo "$(COLOR_BLUE)Packaging Helm chart...$(COLOR_RESET)"
	helm package $(CHART_NAME)

.PHONY: template
template: ## Render chart templates locally
	@echo "$(COLOR_BLUE)Rendering chart templates...$(COLOR_RESET)"
	helm template $(RELEASE_NAME) $(CHART_NAME) --namespace $(NAMESPACE)

.PHONY: template-replication
template-replication: ## Render templates with replication
	@echo "$(COLOR_BLUE)Rendering chart templates with replication...$(COLOR_RESET)"
	helm template $(RELEASE_NAME) $(CHART_NAME) -f examples/replication.values.yaml --namespace $(NAMESPACE)

.PHONY: template-backup
template-backup: ## Render templates with backup
	@echo "$(COLOR_BLUE)Rendering chart templates with backup...$(COLOR_RESET)"
	helm template $(RELEASE_NAME) $(CHART_NAME) -f examples/replication-and-backup.values.yaml --namespace $(NAMESPACE)

# ==============================================================================
# Deployment
# ==============================================================================

.PHONY: deploy
deploy: ## Deploy MongoDB (basic standalone)
	@echo "$(COLOR_BLUE)Deploying MongoDB (standalone)...$(COLOR_RESET)"
	helm install $(RELEASE_NAME) $(CHART_NAME) \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait

.PHONY: deploy-replication
deploy-replication: ## Deploy MongoDB with replication
	@echo "$(COLOR_BLUE)Deploying MongoDB with replication...$(COLOR_RESET)"
	helm install $(RELEASE_NAME) $(CHART_NAME) \
		-f examples/replication.values.yaml \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait

.PHONY: deploy-with-backup
deploy-with-backup: ## Deploy MongoDB with replication and S3 backups
	@echo "$(COLOR_BLUE)Deploying MongoDB with replication and backups...$(COLOR_RESET)"
	@sleep 5
	helm install $(RELEASE_NAME) $(CHART_NAME) \
		-f examples/replication-and-backup.values.yaml \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait

.PHONY: upgrade
upgrade: ## Upgrade existing deployment
	@echo "$(COLOR_BLUE)Upgrading MongoDB deployment...$(COLOR_RESET)"
	helm upgrade $(RELEASE_NAME) $(CHART_NAME) \
		--namespace $(NAMESPACE) \
		--wait

.PHONY: uninstall
uninstall: ## Uninstall the Helm release
	@echo "$(COLOR_YELLOW)Uninstalling MongoDB...$(COLOR_RESET)"
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

.PHONY: hard-uninstall
hard-uninstall: ## Hard uninstall (remove Helm release + all PVCs)
	@echo "$(COLOR_YELLOW)Hard uninstalling MongoDB (removing Helm release and PVCs)...$(COLOR_RESET)"
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE) || true
	@echo "$(COLOR_YELLOW)Removing PVCs...$(COLOR_RESET)"
	kubectl delete pvc -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME) --ignore-not-found
	@echo "$(COLOR_GREEN)Hard uninstall complete$(COLOR_RESET)"

.PHONY: clean
clean: uninstall minio-remove ## Clean up everything (uninstall + remove MinIO)
	@echo "$(COLOR_GREEN)Cleanup complete$(COLOR_RESET)"

# ==============================================================================
# Status and Monitoring
# ==============================================================================

.PHONY: status
status: ## Show deployment status
	@echo "$(COLOR_BOLD)Helm Release:$(COLOR_RESET)"
	helm status $(RELEASE_NAME) --namespace $(NAMESPACE)
	@echo ""
	@echo "$(COLOR_BOLD)Pods:$(COLOR_RESET)"
	kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME)

.PHONY: watch
watch: ## Watch pod status
	kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME) -w

.PHONY: describe-pod
describe-pod: ## Describe the first pod
	kubectl describe pod -n $(NAMESPACE) $(RELEASE_NAME)-$(CHART_NAME)-0

.PHONY: logs
logs: ## Show logs from primary pod
	kubectl logs -n $(NAMESPACE) $(RELEASE_NAME)-$(CHART_NAME)-0

.PHONY: logs-follow
logs-follow: ## Follow logs from primary pod
	kubectl logs -n $(NAMESPACE) $(RELEASE_NAME)-$(CHART_NAME)-0 -f

.PHONY: logs-replica
logs-replica: ## Show logs from first replica (pod-1)
	kubectl logs -n $(NAMESPACE) $(RELEASE_NAME)-$(CHART_NAME)-1

# ==============================================================================
# Database Operations
# ==============================================================================

.PHONY: get-password
get-password: ## Get MongoDB root password
	@echo "$(COLOR_BOLD)MongoDB Root Password:$(COLOR_RESET)"
	@kubectl get secret --namespace $(NAMESPACE) $(RELEASE_NAME)-$(CHART_NAME)-mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d
	@echo ""

.PHONY: shell
shell: ## Open shell in primary pod
	kubectl exec -it -n $(NAMESPACE) $(RELEASE_NAME)-$(CHART_NAME)-0 -- /bin/bash

.PHONY: connect
connect: ## Connect to MongoDB via mongosh
	@echo "$(COLOR_BLUE)Connecting to MongoDB...$(COLOR_RESET)"
	kubectl exec -it -n $(NAMESPACE) $(RELEASE_NAME)-$(CHART_NAME)-0 -- mongosh --username admin --password $$(kubectl get secret --namespace $(NAMESPACE) $(RELEASE_NAME)-$(CHART_NAME)-mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d) --authenticationDatabase admin

.PHONY: port-forward
port-forward: ## Port-forward to access MongoDB locally
	@echo "$(COLOR_BLUE)Port forwarding MongoDB to localhost:27017...$(COLOR_RESET)"
	kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME)-$(CHART_NAME)-primary 27017:27017

# ==============================================================================
# Replication Operations
# ==============================================================================

.PHONY: check-replication
check-replication: ## Check replica set status
	@echo "$(COLOR_BLUE)Checking replica set status...$(COLOR_RESET)"
	kubectl exec -n $(NAMESPACE) $(RELEASE_NAME)-$(CHART_NAME)-0 -- mongosh --username admin --password $$(kubectl get secret --namespace $(NAMESPACE) $(RELEASE_NAME)-$(CHART_NAME)-mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d) --authenticationDatabase admin --eval "rs.status()"

.PHONY: init-replica-logs
init-replica-logs: ## Show logs from replica set initialization job
	@echo "$(COLOR_BLUE)Showing replica set initialization logs...$(COLOR_RESET)"
	kubectl logs -n $(NAMESPACE) -l component=init-replica --tail=200

# ==============================================================================
# Backup Operations
# ==============================================================================

.PHONY: trigger-backup
trigger-backup: ## Manually trigger a backup job
	@echo "$(COLOR_BLUE)Triggering manual backup...$(COLOR_RESET)"
	kubectl create job --namespace $(NAMESPACE) --from=cronjob/$(RELEASE_NAME)-$(CHART_NAME)-backup manual-backup-$$(date +%s)

.PHONY: check-backups
check-backups: ## Check backup job status
	kubectl get jobs -n $(NAMESPACE) -l component=backup

.PHONY: backup-logs
backup-logs: ## Show logs from latest backup job
	@echo "$(COLOR_BLUE)Showing logs from latest backup job...$(COLOR_RESET)"
	kubectl logs -n $(NAMESPACE) -l component=backup --tail=100

# ==============================================================================
# Testing
# ==============================================================================

.PHONY: test
test: ## Run Helm tests
	@echo "$(COLOR_BLUE)Running Helm tests...$(COLOR_RESET)"
	helm test $(RELEASE_NAME) --namespace $(NAMESPACE)

.PHONY: quick-test
quick-test: deploy test ## Quick test: deploy and run tests
	@echo "$(COLOR_GREEN)Quick test complete!$(COLOR_RESET)"

.PHONY: full-test
full-test: lint deploy-replication test ## Full test: lint, deploy with replication, and test
	@echo "$(COLOR_GREEN)Full test complete!$(COLOR_RESET)"

.PHONY: reset
reset: clean deploy ## Reset: clean and redeploy
	@echo "$(COLOR_GREEN)Reset complete!$(COLOR_RESET)"
