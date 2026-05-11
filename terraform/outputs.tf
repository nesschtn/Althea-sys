output "public_ip" {
  description = "Adresse IP publique de la VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "fqdn" {
  description = "Nom DNS public Azure"
  value       = azurerm_public_ip.pip.fqdn
}

output "url" {
  description = "URL HTTP du site"
  value       = "http://${azurerm_public_ip.pip.fqdn}"
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à la VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.pip.fqdn}"
}

output "resource_group" {
  description = "Nom du resource group créé"
  value       = azurerm_resource_group.rg.name
}
