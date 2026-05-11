variable "project_name" {
  description = "Nom court du projet (utilisé pour préfixer les ressources)"
  type        = string
  default     = "projet-etude"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "project_name doit être en minuscules/chiffres/tirets, 3-20 caractères."
  }
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "francecentral"
}

variable "vm_size" {
  description = "Taille de la VM. B1s = 1 vCPU, 1 GB RAM (économique pour étude)"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Nom d'utilisateur SSH"
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "Clé SSH publique. Générer avec: ssh-keygen -t ed25519 -f ~/.ssh/azure_etude"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR autorisé pour SSH (par défaut ouvert - à restreindre en prod)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Tags appliqués à toutes les ressources"
  type        = map(string)
  default = {
    environment = "study"
    managed_by  = "terraform"
    project     = "nginx-deployment"
  }
}
