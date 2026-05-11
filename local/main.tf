# =============================================================================
# Althea-sys - Deploiement local Docker
# Reverse proxy nginx + backend nginx, orchestres par Terraform
# =============================================================================

locals {
  base_name = "${var.project_name}-${var.environment}"

  # Labels Docker (Terraform docker provider attend une liste d'objets)
  common_labels = [
    for k, v in var.labels : {
      label = k
      value = v
    }
  ]
}

# -----------------------------------------------------------------------------
# Reseau Docker dedie : isolation des conteneurs du projet
# -----------------------------------------------------------------------------
resource "docker_network" "althea" {
  name   = "${local.base_name}-network"
  driver = "bridge"

  ipam_config {
    subnet = var.network_subnet
  }

  dynamic "labels" {
    for_each = local.common_labels
    content {
      label = labels.value.label
      value = labels.value.value
    }
  }
}

# -----------------------------------------------------------------------------
# Image nginx (pullee une fois, reutilisee par les 2 conteneurs)
# -----------------------------------------------------------------------------
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

# -----------------------------------------------------------------------------
# Conteneur backend web - sert la page HTML d'Althea
# -----------------------------------------------------------------------------
resource "docker_container" "web" {
  name  = "${local.base_name}-web"
  image = docker_image.nginx.image_id

  networks_advanced {
    name = docker_network.althea.name
    # Alias DNS interne : le proxy pourra l'atteindre via "web"
    aliases = ["web"]
  }

  # Pas de port expose vers l'hote : on passe forcement par le proxy
  # (defense en profondeur : le backend n'est pas accessible directement)

  restart = "unless-stopped"

  healthcheck {
    test         = ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/"]
    interval     = "30s"
    timeout      = "5s"
    retries      = 3
    start_period = "5s"
  }

  dynamic "labels" {
    for_each = local.common_labels
    content {
      label = labels.value.label
      value = labels.value.value
    }
  }

  labels {
    label = "role"
    value = "web-backend"
  }
}

# -----------------------------------------------------------------------------
# Conteneur reverse proxy - point d'entree HTTP, expose sur l'hote
# -----------------------------------------------------------------------------
resource "docker_container" "proxy" {
  name  = "${local.base_name}-proxy"
  image = docker_image.nginx.image_id

  networks_advanced {
    name    = docker_network.althea.name
    aliases = ["proxy"]
  }

  ports {
    internal = 80
    external = var.proxy_external_port
    protocol = "tcp"
  }

  restart = "unless-stopped"

  depends_on = [docker_container.web]

  healthcheck {
    test         = ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/"]
    interval     = "30s"
    timeout      = "5s"
    retries      = 3
    start_period = "5s"
  }

  dynamic "labels" {
    for_each = local.common_labels
    content {
      label = labels.value.label
      value = labels.value.value
    }
  }

  labels {
    label = "role"
    value = "reverse-proxy"
  }
}
