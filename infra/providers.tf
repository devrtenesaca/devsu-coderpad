terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.79.0"

    }
  }
}

provider "azurerm" {
  features {}

}

terraform {
  #the backend configuration is set in the Makefile to allow dynamic values for the storage account and resource group
  backend "azurerm" {}
  }

