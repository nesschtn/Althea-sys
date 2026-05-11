#!/usr/bin/env bash
# =============================================================================
# Althea-sys - Setup automatique du dossier local/
# Cree toute l'arborescence + tous les fichiers necessaires.
# A lancer depuis la racine du repo Althea-sys.
# =============================================================================

set -euo pipefail

echo "==> Verification du repertoire courant..."
if [ ! -d ".git" ]; then
  echo "ERREUR : ce script doit etre lance depuis la racine du repo Althea-sys."
  echo "Fais 'cd ~/projects/Althea-sys' d'abord."
  exit 1
fi

# Si un dossier local/ existe avec des fichiers en vrac, on le degage proprement
if [ -d "local" ]; then
  echo "==> Suppression de l'ancien dossier local/ (s'il existait)..."
  rm -rf local
fi

echo "==> Creation de l'arborescence local/..."
mkdir -p local/terraform
mkdir -p local/ansible/roles/nginx-web/tasks
mkdir -p local/ansible/roles/nginx-web/templates
mkdir -p local/ansible/roles/nginx-proxy/tasks
mkdir -p local/ansible/roles/nginx-proxy/templates

# -----------------------------------------------------------------------------
# Terraform
# -----------------------------------------------------------------------------
echo "==> Generation des fichiers Terraform..."

cat > local/terraform/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}
EOF

cat > local/terraform/variables.tf <<'EOF'
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
EOF

cat > local/terraform/main.tf <<'EOF'
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
EOF

cat > local/terraform/outputs.tf <<'EOF'
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
  description = "Inventaire Ansible pret a l'emploi"
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
EOF

# -----------------------------------------------------------------------------
# Ansible
# -----------------------------------------------------------------------------
echo "==> Generation des fichiers Ansible..."

cat > local/ansible/ansible.cfg <<'EOF'
[defaults]
inventory            = inventory.ini
host_key_checking    = False
retry_files_enabled  = False
deprecation_warnings = False
stdout_callback      = yaml
interpreter_python   = auto_silent

[ssh_connection]
pipelining = True
EOF

cat > local/ansible/playbook.yml <<'EOF'
---
- name: Configure backend web container
  hosts: web
  gather_facts: false
  become: true
  vars:
    project_name: althea-sys
    environment_name: dev
  roles:
    - nginx-web

- name: Configure reverse proxy container
  hosts: proxy
  gather_facts: false
  become: true
  vars:
    backend_host: web
    backend_port: 80
  roles:
    - nginx-proxy
EOF

cat > local/ansible/roles/nginx-web/tasks/main.yml <<'EOF'
---
- name: Deploy Althea index page
  ansible.builtin.template:
    src: index.html.j2
    dest: /usr/share/nginx/html/index.html
    owner: root
    group: root
    mode: '0644'

- name: Deploy nginx site config (backend)
  ansible.builtin.template:
    src: default.conf.j2
    dest: /etc/nginx/conf.d/default.conf
    owner: root
    group: root
    mode: '0644'

- name: Reload nginx
  ansible.builtin.command: nginx -s reload
  changed_when: true
EOF

cat > local/ansible/roles/nginx-web/templates/index.html.j2 <<'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{ project_name }} - {{ environment_name }}</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
      background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #fff;
      padding: 2rem;
    }
    .card {
      background: rgba(255, 255, 255, 0.1);
      backdrop-filter: blur(10px);
      border-radius: 16px;
      padding: 3rem;
      max-width: 720px;
      width: 100%;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
      border: 1px solid rgba(255, 255, 255, 0.18);
    }
    h1 {
      font-size: 2.5rem;
      margin-bottom: 0.5rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
    .badge {
      display: inline-block;
      background: rgba(0, 200, 100, 0.2);
      border: 1px solid rgba(0, 200, 100, 0.5);
      padding: 0.25rem 0.75rem;
      border-radius: 20px;
      font-size: 0.85rem;
      font-weight: 500;
    }
    .subtitle { opacity: 0.8; margin-bottom: 2rem; }
    .stack { display: grid; gap: 0.75rem; margin-top: 2rem; }
    .stack-item {
      display: flex;
      align-items: center;
      gap: 1rem;
      padding: 0.75rem 1rem;
      background: rgba(255, 255, 255, 0.05);
      border-radius: 8px;
      border-left: 3px solid #4ade80;
    }
    .stack-item strong { color: #fff; min-width: 140px; }
    .stack-item span { opacity: 0.85; font-size: 0.9rem; }
    footer {
      margin-top: 2rem;
      padding-top: 1.5rem;
      border-top: 1px solid rgba(255, 255, 255, 0.1);
      font-size: 0.85rem;
      opacity: 0.7;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>{{ project_name }} <span class="badge">{{ environment_name }}</span></h1>
    <p class="subtitle">Deploiement reussi - infrastructure orchestree par Terraform et configuree par Ansible.</p>

    <div class="stack">
      <div class="stack-item">
        <strong>Provisioning</strong>
        <span>Terraform (provider kreuzwerker/docker)</span>
      </div>
      <div class="stack-item">
        <strong>Configuration</strong>
        <span>Ansible (connexion via docker, sans SSH)</span>
      </div>
      <div class="stack-item">
        <strong>Reverse proxy</strong>
        <span>nginx 1.27 sur Alpine Linux</span>
      </div>
      <div class="stack-item">
        <strong>Backend web</strong>
        <span>nginx 1.27 (cette page)</span>
      </div>
      <div class="stack-item">
        <strong>Reseau</strong>
        <span>Reseau Docker dedie (isolation backend)</span>
      </div>
      <div class="stack-item">
        <strong>Securite</strong>
        <span>Trivy (scan IaC + images), backend non expose</span>
      </div>
    </div>

    <footer>
      Projet Mastere DevOps - Sup de Vinci
    </footer>
  </div>
</body>
</html>
EOF

cat > local/ansible/roles/nginx-web/templates/default.conf.j2 <<'EOF'
server {
    listen       80 default_server;
    server_name  _;

    root   /usr/share/nginx/html;
    index  index.html;

    server_tokens off;

    location / {
        try_files $uri $uri/ =404;
    }

    location = /healthz {
        access_log off;
        add_header Content-Type text/plain;
        return 200 "ok\n";
    }
}
EOF

cat > local/ansible/roles/nginx-proxy/tasks/main.yml <<'EOF'
---
- name: Deploy reverse proxy nginx config
  ansible.builtin.template:
    src: proxy.conf.j2
    dest: /etc/nginx/conf.d/default.conf
    owner: root
    group: root
    mode: '0644'

- name: Reload nginx
  ansible.builtin.command: nginx -s reload
  changed_when: true
EOF

cat > local/ansible/roles/nginx-proxy/templates/proxy.conf.j2 <<'EOF'
upstream backend {
    server {{ backend_host }}:{{ backend_port }};
    keepalive 16;
}

server {
    listen       80 default_server;
    server_name  _;

    server_tokens off;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location / {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout    30s;
    }

    location = /healthz {
        access_log off;
        add_header Content-Type text/plain;
        return 200 "proxy ok\n";
    }
}
EOF

# -----------------------------------------------------------------------------
# Makefile + README
# -----------------------------------------------------------------------------
echo "==> Generation du Makefile et README..."

cat > local/Makefile <<'EOF'
.DEFAULT_GOAL := help

TF_DIR      := terraform
ANSIBLE_DIR := ansible

.PHONY: help up down restart status logs scan plan apply configure clean

help:
	@echo "Cibles disponibles :"
	@echo "  make up        - Deploie tout (Terraform + Ansible)"
	@echo "  make plan      - Affiche le plan Terraform"
	@echo "  make apply     - Cree les conteneurs"
	@echo "  make configure - Lance Ansible sur les conteneurs"
	@echo "  make scan      - Scan Trivy (IaC + image)"
	@echo "  make status    - Etat des conteneurs"
	@echo "  make logs      - Logs des conteneurs"
	@echo "  make restart   - Redemarre les conteneurs"
	@echo "  make down      - Detruit tout"
	@echo "  make clean     - Detruit + nettoie les fichiers tf locaux"

up: apply configure
	@echo ""
	@echo "==> Deploiement termine !"
	@echo "    Ouvre http://localhost:8080 dans ton navigateur."

plan:
	cd $(TF_DIR) && terraform init -upgrade && terraform plan

apply:
	cd $(TF_DIR) && terraform init -upgrade && terraform apply -auto-approve
	@echo "==> Generation de l'inventaire Ansible..."
	cd $(TF_DIR) && terraform output -raw ansible_inventory > ../$(ANSIBLE_DIR)/inventory.ini
	@echo "==> Inventaire genere :"
	@cat $(ANSIBLE_DIR)/inventory.ini

configure:
	cd $(ANSIBLE_DIR) && ansible-playbook playbook.yml

scan:
	@echo "==> Scan IaC (Terraform)..."
	-trivy config $(TF_DIR)
	@echo ""
	@echo "==> Scan image nginx..."
	-trivy image --severity HIGH,CRITICAL nginx:1.27-alpine

status:
	docker ps --filter "label=project=althea-sys"

logs:
	docker logs althea-dev-proxy --tail 20
	@echo ""
	docker logs althea-dev-web --tail 20

restart:
	docker restart althea-dev-proxy althea-dev-web

down:
	cd $(TF_DIR) && terraform destroy -auto-approve
	rm -f $(ANSIBLE_DIR)/inventory.ini

clean: down
	rm -rf $(TF_DIR)/.terraform $(TF_DIR)/terraform.tfstate*
	rm -f $(ANSIBLE_DIR)/inventory.ini
EOF

cat > local/README.md <<'EOF'
# Althea-sys - Deploiement local Docker

Stack reverse proxy + backend web provisionnee par Terraform et configuree par Ansible, sans dependance cloud.

## Demarrage rapide

```bash
cd local/
make up
```

Ouvre http://localhost:8080 dans ton navigateur.

## Pre-requis

- WSL2 + Ubuntu (ou Linux natif)
- Docker (Docker Desktop ou Docker Engine)
- Terraform >= 1.5
- Ansible >= 2.15
- Module Python docker (pip install docker)
- Trivy (optionnel, pour les scans)

## Commandes

| Commande | Description |
|---|---|
| make up | Deploie tout |
| make plan | Plan Terraform |
| make scan | Scan securite |
| make status | Etat des conteneurs |
| make logs | Logs |
| make down | Detruit tout |
| make clean | Detruit + nettoie |
EOF

echo ""
echo "==> Termine ! Arborescence creee :"
echo ""
if command -v tree &> /dev/null; then
  tree local/
else
  find local/ -type f
fi
echo ""
echo "==> Prochaine etape :"
echo "    cd local/ && make up"
