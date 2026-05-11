# =============================================================================
# Althea-sys - Deploiement local Docker avec observability
# Web stack : reverse proxy + backend
# Observability : 2x nginx-exporter + prometheus + grafana
# =============================================================================

locals {
  base_name = "${var.project_name}-${var.environment}"

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
# Images (toutes pullees une seule fois)
# -----------------------------------------------------------------------------
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
}

resource "docker_image" "nginx_exporter" {
  name         = "nginx/nginx-prometheus-exporter:1.3"
  keep_locally = true
}

resource "docker_image" "prometheus" {
  name         = "prom/prometheus:v2.55.0"
  keep_locally = true
}

resource "docker_image" "grafana" {
  name         = "grafana/grafana:11.3.0"
  keep_locally = true
}

# -----------------------------------------------------------------------------
# Conteneur backend web
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Conteneur reverse proxy (expose 8080)
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

# -----------------------------------------------------------------------------
# Exporter Prometheus pour le backend web
# Scrappe /stub_status sur le conteneur "web" et expose au format Prometheus
# -----------------------------------------------------------------------------
resource "docker_container" "nginx_exporter_web" {
  name  = "${local.base_name}-exporter-web"
  image = docker_image.nginx_exporter.image_id

  networks_advanced {
    name    = docker_network.althea.name
    aliases = ["exporter-web"]
  }

  command = [
    "--nginx.scrape-uri=http://web/stub_status"
  ]

  restart    = "unless-stopped"
  depends_on = [docker_container.web]

  dynamic "labels" {
    for_each = local.common_labels
    content {
      label = labels.value.label
      value = labels.value.value
    }
  }

  labels {
    label = "role"
    value = "metrics-exporter"
  }
}

# -----------------------------------------------------------------------------
# Exporter Prometheus pour le reverse proxy
# -----------------------------------------------------------------------------
resource "docker_container" "nginx_exporter_proxy" {
  name  = "${local.base_name}-exporter-proxy"
  image = docker_image.nginx_exporter.image_id

  networks_advanced {
    name    = docker_network.althea.name
    aliases = ["exporter-proxy"]
  }

  command = [
    "--nginx.scrape-uri=http://proxy/stub_status"
  ]

  restart    = "unless-stopped"
  depends_on = [docker_container.proxy]

  dynamic "labels" {
    for_each = local.common_labels
    content {
      label = labels.value.label
      value = labels.value.value
    }
  }

  labels {
    label = "role"
    value = "metrics-exporter"
  }
}

# -----------------------------------------------------------------------------
# Prometheus (scrape les exporters, expose UI sur 9090)
# -----------------------------------------------------------------------------
resource "docker_container" "prometheus" {
  name  = "${local.base_name}-prometheus"
  image = docker_image.prometheus.image_id

  networks_advanced {
    name    = docker_network.althea.name
    aliases = ["prometheus"]
  }

  ports {
    internal = 9090
    external = var.prometheus_external_port
    protocol = "tcp"
  }

  restart = "unless-stopped"

  depends_on = [
    docker_container.nginx_exporter_web,
    docker_container.nginx_exporter_proxy,
  ]

  dynamic "labels" {
    for_each = local.common_labels
    content {
      label = labels.value.label
      value = labels.value.value
    }
  }

  labels {
    label = "role"
    value = "monitoring-prometheus"
  }
}

# -----------------------------------------------------------------------------
# Grafana (UI dashboards sur 3000)
# -----------------------------------------------------------------------------
resource "docker_container" "grafana" {
  name  = "${local.base_name}-grafana"
  image = docker_image.grafana.image_id

  networks_advanced {
    name    = docker_network.althea.name
    aliases = ["grafana"]
  }

  ports {
    internal = 3000
    external = var.grafana_external_port
    protocol = "tcp"
  }

  env = [
    "GF_SECURITY_ADMIN_USER=${var.grafana_admin_user}",
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_admin_password}",
    "GF_AUTH_ANONYMOUS_ENABLED=false",
    "GF_USERS_ALLOW_SIGN_UP=false",
  ]

  restart    = "unless-stopped"
  depends_on = [docker_container.prometheus]

  dynamic "labels" {
    for_each = local.common_labels
    content {
      label = labels.value.label
      value = labels.value.value
    }
  }

  labels {
    label = "role"
    value = "monitoring-grafana"
  }
}
