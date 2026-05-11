locals {
  base_name = "${var.project_name}-${var.environment}"

  common_labels = [
    for k, v in var.labels : {
      label = k
      value = v
    }
  ]
}

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

resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_container" "web" {
  name  = "${local.base_name}-web"
  image = docker_image.nginx.image_id

  networks_advanced {
    name    = docker_network.althea.name
    aliases = ["web"]
  }

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
