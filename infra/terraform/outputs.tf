output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "acr_name" {
  value = azurerm_container_registry.main.name
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "aks_name" {
  value       = var.enable_aks ? azurerm_kubernetes_cluster.main[0].name : null
  description = "Récupérer le kubeconfig: az aks get-credentials -g <rg> -n <aks_name>"
}

output "sql_server_fqdn" {
  value = var.enable_sql ? azurerm_mssql_server.main[0].fully_qualified_domain_name : null
}

output "agent_vm_public_ip" {
  value       = var.enable_agent_vm ? azurerm_public_ip.agent[0].ip_address : null
  description = "IP à mettre dans l'inventory Ansible."
}
