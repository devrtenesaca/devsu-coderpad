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
NAMESPACE ?= devsu-app
#IMAGE_TAG      ?= $(shell git rev-parse --short HEAD)

.PHONY: tf-init backend-init tf-fmt tf-validate tf-apply tf-destroy deploy-infra-aks get-url
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
	docker build --platform linux/amd64 -t $(ACR_SERVER)/$(IMAGE_NAME):$(IMAGE_TAG) -t $(ACR_SERVER)/$(IMAGE_NAME):latest .
	docker push $(ACR_SERVER)/$(IMAGE_NAME):$(IMAGE_TAG)
	docker push $(ACR_SERVER)/$(IMAGE_NAME):latest
	@echo "==> ✅ Imagenes subidas con tags: $(IMAGE_TAG) y latest"


# ---deploy to AKS---
app-deploy:
	@echo "==> 1. Connecting to existing AKS..."
	az aks get-credentials --resource-group $(RESOURCE_GROUP) --name $(AKS_CLUSTER) --overwrite-existing

	@echo "==> 2. Ensuring Namespace exists..."
	kubectl apply -f aks/00-namespace.yaml

	@echo "==> 3. Deploying ConfigMaps and Secrets..."
	kubectl apply -f aks/02-configmap.yaml -n $(NAMESPACE)
	kubectl apply -f aks/03-secret.yaml -n $(NAMESPACE)
	kubectl apply -f aks/06-api-service.yaml -n $(NAMESPACE)
	kubectl apply -f aks/07-api-hpa.yaml -n $(NAMESPACE)

	@echo "==> 4. Deploying PostgreSQL to AKS..."
	kubectl apply -f aks/01-postgres.yaml -n $(NAMESPACE)
	kubectl rollout status deployment/postgres-deployment -n $(NAMESPACE) --timeout=120s

	@echo "==> 5. Running Database Migrations..."
	kubectl delete job django-migration-job -n $(NAMESPACE) --ignore-not-found
	sed -i.bak 's|image:.*|image: $(ACR_SERVER)/$(IMAGE_NAME):$(IMAGE_TAG)|g' aks/04-migration-job.yaml
	kubectl apply -f aks/04-migration-job.yaml -n $(NAMESPACE)
	kubectl wait --for=condition=complete job/django-migration-job -n $(NAMESPACE) --timeout=60s

	@echo "==> 6. Deploying the app..."
	kubectl apply -f aks/05-api-deployment.yaml -n $(NAMESPACE)
	kubectl set image deployment/demo-api-deployment api=$(ACR_SERVER)/$(IMAGE_NAME):$(IMAGE_TAG) -n $(NAMESPACE)
	kubectl rollout status deployment/demo-api-deployment -n $(NAMESPACE) --timeout=120s

	@echo "==> ✅ Despliegue completado con éxito en el namespace '$(NAMESPACE)'."


get-url: ## Muestra la URL pública del endpoint en Azure
	@IP=$$(kubectl get svc demo-api-service -n $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	echo "==> 🌐 Endpoint Público: http://$$IP/api/users/"


deploy-infra-aks:
	@echo "Deploying infrastructure for AKS..."
	$(MAKE) tf-init
	$(MAKE) tf-fmt
	$(MAKE) tf-validate
	$(MAKE) tf-apply

deploy-app:
	@echo "Deploying application to AKS..."
	$(MAKE) app-build-push
	$(MAKE) app-deploy

delete-app:
	@echo "Deleting application from AKS..."
	kubectl delete namespace $(NAMESPACE) --ignore-not-found	
	
