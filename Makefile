PREFIX ?= devsu
TF_DIR ?= infra
AZURE_LOCATION          ?= eastus2
TF_STATE_RG             ?= rg-terraform-state-$(PREFIX)
TF_STATE_STORAGE_ACCOUNT?= tfstatertenesacadevsu
TF_STATE_CONTAINER      ?= tfstate
TF_STATE_KEY            ?= aks.terraform.tfstate
TAG=coderpad
#variables for image build
RESOURCE_GROUP ?= devsu-rg-aks
AKS_CLUSTER    ?= devsu-aks-cluster
ACR_NAME       ?= devsuacr
ACR_SERVER     ?= $(ACR_NAME).azurecr.io
IMAGE_NAME     ?= demo-devops-python
IMAGE_TAG      ?= $(shell git rev-parse --short HEAD)

.PHONY: tf-init backend-init tf-fmt tf-validate tf-apply tf-destroy deploy-infra-aks
#-----Backend for Terraform state-----
backend-init:
	@echo "creating resource group for Terraform state..."
	az group create --name $(TF_STATE_RG) --location $(AZURE_LOCATION)
	@echo "creating storage account for Terraform state..."
	az storage account create --name $(TF_STATE_STORAGE_ACCOUNT) --resource-group $(TF_STATE_RG) --location $(AZURE_LOCATION) --sku Standard_LRS
	@echo "creating container for Terraform state..."
	az storage container create --name $(TF_STATE_CONTAINER) --account-name $(TF_STATE_STORAGE_ACCOUNT)	



#-----IaC with Terraform-----


tf-init:
	@echo "Initializing Terraform..."
	cd $(TF_DIR) && terraform init \
		-reconfigure \
		-input=false \
		-backend-config="resource_group_name=$(TF_STATE_RG)" \
		-backend-config="storage_account_name=$(TF_STATE_STORAGE_ACCOUNT)" \
		-backend-config="container_name=$(TF_STATE_CONTAINER)" \
		-backend-config="key=$(TF_STATE_KEY)"

tf-fmt:
	@echo "Formatting Terraform files..."
	cd $(TF_DIR) && terraform fmt -recursive

tf-validate:
	@echo "Validating Terraform files..."
	cd $(TF_DIR) && terraform validate
	
tf-plan:
	@echo "Planning Terraform files..."
	cd $(TF_DIR) && terraform plan -out=tfplan

tf-apply:
	@echo "Applying Terraform files..."
	cd $(TF_DIR) && terraform apply -auto-approve

tf-destroy:
	@echo "Destroying Terraform files..."
	cd $(TF_DIR) && terraform destroy -auto-approve


# ----build and push docker image to ACR----
app-build-push:
	@echo "==> 1. Login en ACR..."
	az acr login --name $(ACR_NAME)

	@echo "==> 2. Build and push image to ACR..."
	docker build -t $(ACR_SERVER)/$(IMAGE_NAME):$(IMAGE_TAG) .
	docker push $(ACR_SERVER)/$(IMAGE_NAME):$(IMAGE_TAG)


# ---deploy to AKS---
app-deploy:
	@echo "==> 3. Connecting to existing AKS..."
	az aks get-credentials --resource-group $(RESOURCE_GROUP) --name $(AKS_CLUSTER) --overwrite-existing

	@echo "==> 2. Deploying PostgreSQL to AKS..."
	kubectl apply -f k8s/postgres.yaml
	@echo "Esperando a que PostgreSQL esté listo..."
	kubectl rollout status deployment/postgres-deployment --timeout=120s

	@echo "==> 3. Deploying ConfigMaps and Secrets..."
	kubectl apply -f k8s/configmap.yaml
	kubectl apply -f k8s/secret.yaml
	kubectl apply -f k8s/service.yaml
	kubectl apply -f k8s/hpa.yaml

	@echo "==> 4. Deploying the app to Kubernetes with the updated image..."
	kubectl apply -f k8s/
	kubectl set image deployment/demo-api-deployment api=$(ACR_SERVER)/$(IMAGE_NAME):$(IMAGE_TAG)
	kubectl rollout status deployment/demo-api-deployment --timeout=120s

	@echo "==> ✅ Despliegue completado con éxito."


deploy-infra-aks:
	@echo "Deploying infrastructure for AKS..."
	$(MAKE) tf-init
	$(MAKE) tf-fmt
	$(MAKE) tf-validate
	$(MAKE) tf-apply
