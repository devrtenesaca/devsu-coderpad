resource "azurerm_resource_group" "rg_aks" {
  name     = "${var.prefix}-rg-aks"
  location = var.location
  tags     = var.tags

}
# creando el ACR
resource "azurerm_container_registry" "acr_registry" {
  name                = "${var.prefix}acr"
  resource_group_name = azurerm_resource_group.rg_aks.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}
#red virtual para aks

resource "azurerm_virtual_network" "vnet_aks" {
  name                = "${var.prefix}-vnet-aks"
  address_space       = [var.vnet_cdir]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_aks.name
  tags                = var.tags

}

resource "azurerm_subnet" "subnet_aks" {
  name                 = "${var.prefix}-subnet-aks"
  resource_group_name  = azurerm_resource_group.rg_aks.name
  virtual_network_name = azurerm_virtual_network.vnet_aks.name
  address_prefixes     = [var.subnet_cdir]
  service_endpoints    = ["Microsoft.ContainerRegistry"]

  depends_on = [azurerm_virtual_network.vnet_aks]
}

#nodepool adicional
resource "azurerm_kubernetes_cluster_node_pool" "user_node_pool" {
  name                  = "usernodepool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster.id
  #vm_size               = "Standard_B2s_v2"
  vm_size               = "Standard_B2ms"
  node_count            = 1
  vnet_subnet_id        = azurerm_subnet.subnet_aks.id
  mode                  = "User"
  auto_scaling_enabled  = true
  node_labels = {
    "nodepool"    = "user"
    "environment" = "development"
    "role"        = "user"
  }
  min_count = 1
  max_count = 1


  tags = var.tags
}


# cracion del cluster aks
resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = "${var.prefix}-aks-cluster"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_aks.name
  dns_prefix          = "${var.prefix}-aks"
  #sku_tier = "Free"

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_B2ms"
    vnet_subnet_id = azurerm_subnet.subnet_aks.id
  }
  identity {
    type = "SystemAssigned"
  }
  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = var.aks_service_cidr
    dns_service_ip    = var.aks_services_dns
  }
}

#agregar el rol para conectar el AKS con el ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks_cluster.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr_registry.id
  skip_service_principal_aad_check = true
}