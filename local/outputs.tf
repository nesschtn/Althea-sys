output "url" {
  description = "URL d'acces au reverse proxy depuis l'hote"
  value       = "http://localhost:${var.proxy_external_port}"
}

output "proxy_container_name" {
  description = "Nom du conteneur reverse proxy"
  value       = docker_container.proxy.name
}

output "web_container_name" {
  description = "Nom du conteneur backend web"
  value       = docker_container.web.name
}

output "network_name" {
  description = "Nom du reseau Docker dedie"
  value       = docker_network.althea.name
}

output "ansible_inventory" {
  description = "Inventaire Ansible pret a l'emploi (a sauvegarder dans inventory.ini)"
  value = <<EOT
[proxy]
${docker_container.proxy.name} ansible_connection=docker

[web]
${docker_container.web.name} ansible_connection=docker

[althea:children]
proxy
web
EOT
}
