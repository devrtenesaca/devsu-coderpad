PREFIX ?= devsu
TF_DIR ?= infra
ANSIBLE_DIR := ansible
INVENTORY := inventory.ini
TAG=coderpad

.PHONY: infra_init infra_fmt infra_validate infra_apply infra_destroy deploy_infra_aks

#-----IaC with Terraform-----

infra_init:
	@echo "Initializing Terraform..."
	cd $(TF_DIR) && terraform init -input=false

infra_fmt:
	@echo "Formatting Terraform files..."
	cd $(TF_DIR) && terraform fmt -recursive

infra_validate:
	@echo "Validating Terraform files..."
	cd $(TF_DIR) && terraform validate

infra_apply:
	@echo "Applying Terraform files..."
	cd $(TF_DIR) && terraform apply -auto-approve

infra_destroy:
	@echo "Destroying Terraform files..."
	cd $(TF_DIR) && terraform destroy -auto-approve

deploy_infra_aks:
	@echo "Deploying infrastructure for AKS..."
	$(MAKE) infra_init
	$(MAKE) infra_fmt
	$(MAKE) infra_validate
	$(MAKE) infra_apply
