PREFIX ?= devsu
TF_DIR ?= infra
AZURE_LOCATION          ?= eastus2
TF_STATE_RG             ?= rg-terraform-state-$(PREFIX)
TF_STATE_STORAGE_ACCOUNT?= tfstatertenesacadevsu
TF_STATE_CONTAINER      ?= tfstate
TF_STATE_KEY            ?= aks.terraform.tfstate
TAG=coderpad


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

tf-apply:
	@echo "Applying Terraform files..."
	cd $(TF_DIR) && terraform apply -auto-approve

tf-destroy:
	@echo "Destroying Terraform files..."
	cd $(TF_DIR) && terraform destroy -auto-approve

deploy-infra-aks:
	@echo "Deploying infrastructure for AKS..."
	$(MAKE) tf-init
	$(MAKE) tf-fmt
	$(MAKE) tf-validate
	$(MAKE) tf-apply
