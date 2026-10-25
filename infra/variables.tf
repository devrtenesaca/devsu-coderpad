variable "prefix" {
  description = "Prefix for resource names"
  type        = string

}
variable "location" {
  description = "Azure region for resource deployment"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    environment = "production"
    created_by  = "terraform"
  }
}

variable "vnet_cdir" {
  description = "CIDR block for the virtual network"
  type        = string

}
variable "subnet_cdir" {
  description = "CIDR block for the subnet"
  type        = string
}

variable "aks_service_cidr" {
  description = "CIDR block for the AKS service"
  type        = string
}
variable "aks_services_dns" {
  description = "DNS service IP for AKS"
  type        = string

}