# Althea-sys — Déploiement local Docker

Stack reverse proxy + backend web provisionnée par **Terraform** et configurée par **Ansible**, sans dépendance cloud.

## Architecture

```
┌────────────────────────────────────────────────────────┐
│ Host (WSL Ubuntu)                                       │
│                                                         │
│  http://localhost:8080                                  │
│         │                                               │
│         ▼                                               │
│   ┌──────────────────────────────────────────┐        │
│   │ Réseau Docker bridge : althea-dev-network│        │
│   │                                           │        │
│   │   ┌─────────────────┐  ┌──────────────┐ │        │
│   │   │ althea-dev-proxy│─▶│althea-dev-web│ │        │
│   │   │ nginx (reverse) │  │ nginx + html │ │        │
│   │   │ port :80        │  │ port :80     │ │        │
│   │   └─────────────────┘  └──────────────┘ │        │
│   │       expose 8080         non exposé    │        │
│   └──────────────────────────────────────────┘        │
└────────────────────────────────────────────────────────┘
```

Le backend n'est **jamais exposé directement** sur l'hôte : toute requête passe par le reverse proxy. C'est un pattern de défense en profondeur classique.

## Pré-requis

- WSL2 + Ubuntu (ou Linux natif)
- Docker (Docker Desktop ou Docker Engine)
- Terraform >= 1.5
- Ansible >= 2.15
- Trivy (optionnel, pour les scans sécurité)
- `make` (souvent déjà installé)

Vérification rapide :

```bash
docker --version
terraform --version
ansible --version
trivy --version
```

## Démarrage rapide

Une seule commande pour tout déployer :

```bash
cd local/
make up
```

Puis ouvre http://localhost:8080 dans ton navigateur.

## Commandes principales

| Commande | Description |
|---|---|
| `make up` | Déploie tout (Terraform + Ansible) |
| `make plan` | Affiche le plan Terraform sans appliquer |
| `make apply` | Crée uniquement les conteneurs (sans configurer) |
| `make configure` | Lance Ansible sur les conteneurs existants |
| `make scan` | Scan sécurité Trivy (IaC + image nginx) |
| `make status` | État des conteneurs |
| `make logs` | Logs des deux conteneurs |
| `make restart` | Redémarre proxy + web |
| `make down` | Détruit tout |
| `make clean` | Détruit + nettoie les fichiers Terraform locaux |

## Vérification manuelle

```bash
# Page web servie par le backend, via le proxy
curl http://localhost:8080/

# Healthcheck du proxy
curl http://localhost:8080/healthz

# Conteneurs en cours
docker ps --filter "label=project=althea-sys"
```

## Personnaliser

Édite `terraform/variables.tf` pour ajuster :
- `proxy_external_port` (par défaut 8080)
- `project_name` / `environment`
- `network_subnet`

Édite `ansible/roles/nginx-web/templates/index.html.j2` pour personnaliser la page.

## DevSecOps : ce qui est scanné

`make scan` lance Trivy sur deux périmètres :

1. **Configuration Terraform** (`trivy config terraform/`) — détecte les misconfigurations (resources sans labels obligatoires, etc.).
2. **Image Docker** (`trivy image nginx:1.27-alpine`) — détecte les CVE HIGH/CRITICAL dans l'image utilisée.

Pour aller plus loin : intégrer le scan dans une GitHub Action pour bloquer un merge si des vulnérabilités HIGH sont trouvées.
