variable "project_name" {
  type        = string
  default     = "althea"
  description = "Nom court du projet, utilisé comme préfixe des ressources."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Nom de l'environnement (dev/test/preprod/prod)."
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "germanywestcentral"
}

variable "enable_aks" {
  type        = bool
  default     = false
  description = "Provisionner AKS. Coût ~30-40$/mois minimum — laisser à false tant que pas nécessaire."
}

variable "enable_sql" {
  type        = bool
  default     = false
  description = "Provisionner Azure SQL Database. Coût ~5$/mois en Basic."
}

variable "enable_agent_vm" {
  type        = bool
  default     = false
  description = "Provisionner la VM Linux servant d'agent CI/CD (cible Ansible). Coût ~8$/mois en B1s."
}

variable "agent_vm_admin_username" {
  type        = string
  default     = "azureuser"
  description = "Utilisateur admin SSH de la VM agent."
}

variable "agent_vm_ssh_public_key" {
  type        = string
  default     = ""
  description = "Clé publique SSH (contenu de ~/.ssh/id_rsa.pub). Requis si enable_agent_vm = true."
}

variable "agent_vm_allowed_ssh_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR autorisé en SSH sur la VM agent. Mettre votre IP perso pour limiter l'exposition."
}
