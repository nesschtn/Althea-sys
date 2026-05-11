output "url_app" {
  description = "URL d'acces a l'application (reverse proxy)"
  value       = "http://localhost:${var.proxy_external_port}"
}

output "url_prometheus" {
  description = "URL de l'UI Prometheus"
  value       = "http://localhost:${var.prometheus_external_port}"
}

output "url_grafana" {
  description = "URL de l'UI Grafana"
  value       = "http://localhost:${var.grafana_external_port}"
}

output "grafana_credentials" {
  description = "Login Grafana (admin user + valeur du mdp via terraform output -raw grafana_admin_password)"
  value       = "User: ${var.grafana_admin_user} / Password: voir variables.tf (par defaut: althea-dev)"
}

output "network_name" {
  description = "Nom du reseau Docker dedie"
  value       = docker_network.althea.name
}

output "containers" {
  description = "Liste des conteneurs deployes"
  value = [
    docker_container.proxy.name,
    docker_container.web.name,
    docker_container.nginx_exporter_proxy.name,
    docker_container.nginx_exporter_web.name,
    docker_container.prometheus.name,
    docker_container.grafana.name,
  ]
}

output "ansible_inventory" {
  description = "Inventaire Ansible (web + proxy + monitoring)"
  value = <<EOT
[proxy]
${docker_container.proxy.name} ansible_connection=docker

[web]
${docker_container.web.name} ansible_connection=docker

[prometheus]
${docker_container.prometheus.name} ansible_connection=docker

[grafana]
${docker_container.grafana.name} ansible_connection=docker

[nginx:children]
proxy
web

[monitoring:children]
prometheus
grafana

[althea:children]
nginx
monitoring
EOT
}
