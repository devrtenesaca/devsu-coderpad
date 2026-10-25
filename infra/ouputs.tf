output "client_certificate" {
  description = "Client certificate for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config.0.client_certificate
  sensitive   = true

}

output "kube_config" {
  description = "Kube config for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks_cluster.kube_config_raw
  sensitive   = true

}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry"
  value       = azurerm_container_registry.acr_registry.login_server
}
output "acr_admin_username" {
  description = "Admin username of the Azure Container Registry"
  value       = azurerm_container_registry.acr_registry.admin_username
}
output "acr_admin_password" {
  description = "Admin password of the Azure Container Registry"
  value       = azurerm_container_registry.acr_registry.admin_password
  sensitive   = true
}