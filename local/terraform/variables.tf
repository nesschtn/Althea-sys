variable "project_name" {
  description = "Prefixe applique a toutes les ressources Docker"
  type        = string
  default     = "althea"
}

variable "environment" {
  description = "Nom de l'environnement (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "proxy_external_port" {
  description = "Port expose sur l'hote pour le reverse proxy"
  type        = number
  default     = 8080
}

variable "prometheus_external_port" {
  description = "Port expose sur l'hote pour l'UI Prometheus"
  type        = number
  default     = 9090
}

variable "grafana_external_port" {
  description = "Port expose sur l'hote pour Grafana"
  type        = number
  default     = 3000
}

variable "grafana_admin_user" {
  description = "Utilisateur admin Grafana (login sur l'UI)"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Mot de passe admin Grafana - A CHANGER avant toute mise en ligne reelle"
  type        = string
  default     = "althea-dev"
  sensitive   = true
}

variable "network_subnet" {
  description = "Sous-reseau du reseau Docker dedie au projet"
  type        = string
  default     = "172.28.0.0/24"
}

variable "labels" {
  description = "Labels appliques a toutes les ressources"
  type        = map(string)
  default = {
    project     = "althea-sys"
    managed_by  = "terraform"
    environment = "dev"
  }
}
