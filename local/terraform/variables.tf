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
  description = "Port expose sur la machine hote pour acceder au reverse proxy"
  type        = number
  default     = 8080
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
