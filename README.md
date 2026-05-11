# Althea-sys

**Projet de Mastère DevOps - Sup de Vinci**

Stack web (reverse proxy + backend) provisionnée par **Terraform** et configurée par **Ansible**, avec scans de sécurité **Trivy** intégrés (approche DevSecOps shift-left).

---

## Sommaire

- [Architecture finale](#architecture-finale)
- [Démarrage rapide](#démarrage-rapide)
- [Stack technique](#stack-technique)
- [Sécurité (DevSecOps)](#sécurité-devsecops)
- [Historique du projet](#historique-du-projet)
- [Structure du dépôt](#structure-du-dépôt)
- [Améliorations envisagées](#améliorations-envisagées)

---

## Architecture finale

```
                       ┌─────────────────────────────┐
                       │      Ton poste (WSL)         │
                       │                              │
   Navigateur ────────▶│  http://localhost:8080       │
                       │           │                  │
                       │           ▼                  │
                       │  ┌──────────────────────┐   │
                       │  │ althea-dev-proxy     │   │
                       │  │ nginx (reverse proxy)│   │
                       │  │ Port 80 → exposé     │   │
                       │  └──────────┬───────────┘   │
                       │             │ HTTP interne   │
                       │             ▼                │
                       │  ┌──────────────────────┐   │
                       │  │ althea-dev-web       │   │
                       │  │ nginx + page HTML    │   │
                       │  │ Port 80 → NON exposé │   │
                       │  └──────────────────────┘   │
                       │                              │
                       │  Réseau Docker dédié         │
                       │  (althea-dev-network)        │
                       └─────────────────────────────┘
```

**Pattern utilisé** : reverse proxy en frontal, backend isolé, pas d'accès direct au backend depuis l'hôte (défense en profondeur).

---

## Démarrage rapide

### Pré-requis

- Linux ou WSL2 avec Ubuntu
- Docker Engine ou Docker Desktop
- Terraform >= 1.5
- Ansible >= 2.16 (`ansible-galaxy collection install community.docker`)
- Make

### Lancer la stack

```bash
cd local/
make up
```

Ouvrir [http://localhost:8080](http://localhost:8080) dans un navigateur.

### Commandes disponibles

| Commande | Effet |
|---|---|
| `make up` | Déploie tout (Terraform + Ansible) |
| `make plan` | Affiche le plan Terraform sans appliquer |
| `make apply` | Crée uniquement les conteneurs |
| `make configure` | Lance Ansible sur les conteneurs existants |
| `make scan` | Scan sécurité Trivy (Terraform + image Docker) |
| `make status` | État des conteneurs |
| `make logs` | Logs des deux conteneurs |
| `make down` | Détruit tout |
| `make clean` | Détruit + nettoie les fichiers Terraform locaux |

---

## Stack technique

### Provisionnement — Terraform

- **Provider** : `kreuzwerker/docker` (~> 3.0)
- **Ressources** :
  - `docker_network` : réseau bridge dédié (isolation des conteneurs du projet)
  - `docker_image` : image nginx 1.27-alpine (pull une fois, réutilisée)
  - `docker_container` × 2 : reverse proxy + backend web
- **Labels** : tous les conteneurs sont labellisés (`project=althea-sys`, `managed_by=terraform`, etc.) pour faciliter le filtrage et le monitoring.
- **Healthchecks** : chaque conteneur dispose d'un `HEALTHCHECK` Docker actif.

### Configuration — Ansible

- **Connexion** : exécution déléguée (`connection: local`), pas de SSH ni de Python requis dans les conteneurs.
- **Modules clés** :
  - `community.docker.docker_container_copy_into` : copie de fichiers vers les conteneurs via l'API Docker
  - `community.docker.docker_container_exec` : exécution de commandes (`nginx -s reload`)
- **Rôles** :
  - `nginx-web` : déploie la page HTML et la config nginx du backend
  - `nginx-proxy` : déploie la config nginx du reverse proxy

### Tests

Le `make up` se termine par un déploiement fonctionnel. Test manuel :

```bash
curl http://localhost:8080/         # page Althea
curl http://localhost:8080/healthz  # healthcheck du proxy
docker exec althea-dev-web wget -qO- http://localhost/healthz  # healthcheck backend
```

---

## Sécurité (DevSecOps)

Le scan `make scan` lance Trivy sur deux périmètres :

### 1. IaC (Terraform)

```bash
trivy config local/terraform/
```

Détecte :
- Misconfigurations Docker (conteneurs root, absence de limites de ressources)
- Labels manquants
- Versions de provider obsolètes

### 2. Image Docker

```bash
trivy image --severity HIGH,CRITICAL nginx:1.27-alpine
```

Détecte les CVE HIGH/CRITICAL dans l'image utilisée. Comme `nginx:1.27-alpine` est une image minimaliste récente, les findings sont peu nombreux.

### Bonnes pratiques appliquées

- Backend non exposé sur l'hôte → impossible d'accéder directement à `althea-dev-web` depuis l'extérieur
- Image Alpine minimaliste (~10 Mo) → surface d'attaque réduite
- `server_tokens off` dans nginx → masque la version dans les en-têtes HTTP
- En-têtes de sécurité sur le reverse proxy (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`)
- Healthchecks → détection rapide d'un service défaillant
- Réseau Docker isolé → pas de pollution du réseau hôte

---

## Historique du projet

Le projet a évolué au gré des contraintes rencontrées, ce qui constitue en soi une partie de la démonstration DevOps.

### Phase 1 — Architecture cible : Azure

L'objectif initial était de déployer une VM Linux Ubuntu sur Azure (provider `azurerm`), configurée par Ansible, avec un pipeline CI/CD complet :

- **Source** : GitHub
- **CI/CD** : Azure DevOps (avec mirror GitHub → Azure Repos pour vitrine portfolio)
- **Stages** : Validate → Security Scan (tfsec/Trivy) → Plan → Apply (avec approbation manuelle) → Configure (Ansible) → Smoke Test
- **Backend Terraform** : Azure Storage Account avec authentification via Workload Identity Federation

Le code Terraform correspondant est conservé dans `terraform/` et `infra/terraform/` (à titre de référence).

### Phase 2 — Blocage IAM

Le tenant Microsoft Entra ID de Sup de Vinci interdit la création d'App Registrations et de Service Principals par les comptes étudiants. Cette restriction empêchait :

1. La création automatique de Service Connection Azure depuis Azure DevOps
2. La création manuelle de SP via `az ad sp create-for-rbac`

Cette contrainte de gouvernance IAM est courante en entreprise (notamment dans les contextes régulés). Une demande à l'administrateur du tenant pourrait débloquer la situation, mais hors du périmètre temporel du projet.

### Phase 3 — Self-hosted agent

Pour contourner la nécessité d'un Service Principal, un **agent Azure DevOps auto-hébergé** sur le poste de travail a été configuré. L'authentification Azure utilise alors le contexte `az login` local de l'utilisateur, sans SP.

Cette approche fonctionnelle a été abandonnée à l'étape suivante.

### Phase 4 — Blocage capacity SKU

Azure for Students restreint les tailles de VM disponibles. Les SKUs B-series classiques (`Standard_B1s`, `Standard_B2s`) sont marquées `SkuNotAvailable` en `germanywestcentral`. La SKU `Standard_D2pds_v6` était disponible mais sur architecture ARM, ce qui demandait une image Ubuntu ARM64 spécifique et des ajustements supplémentaires sans valeur pédagogique.

### Phase 5 — Bascule Docker local

Décision pragmatique : reproduire l'architecture en local avec Docker. Le code Terraform et Ansible reste de la même nature (IaC + config management), mais avec un provider Docker au lieu d'azurerm. C'est le code dans `local/` qui est aujourd'hui fonctionnel.

**Ce qu'on perd** : déploiement cloud public, IP publique, DNS Azure.
**Ce qu'on gagne** : reproductibilité 100% sur n'importe quel poste, démo qui fonctionne offline, indépendance des quotas étudiants.

---

## Structure du dépôt

```
Althea-sys/
├── local/                          ← Déploiement fonctionnel (Docker)
│   ├── terraform/                  ← Provider kreuzwerker/docker
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   ├── ansible/
│   │   ├── ansible.cfg
│   │   ├── playbook.yml
│   │   └── roles/
│   │       ├── nginx-web/
│   │       └── nginx-proxy/
│   ├── Makefile                    ← Commandes simplifiées
│   ├── README.md
│   └── .gitignore
│
├── terraform/                      ← Référence : Terraform Azure (VM simple)
├── infra/                          ← Référence : Terraform Azure (architecture complète AKS)
├── ansible/                        ← Référence : playbook Ansible Azure
├── bootstrap/                      ← Script de bootstrap backend Azure Storage
├── tests/                          ← Scripts de tests de charge et smoke tests
├── app/                            ← Page web statique (référence)
├── azure-pipelines.yml             ← Référence : pipeline Azure DevOps
├── MIRROR-SETUP.md                 ← Doc du mirror GitHub → Azure Repos
└── PIPELINE-SETUP.md               ← Doc du pipeline Azure DevOps
```

Les dossiers `terraform/`, `infra/`, `ansible/` et les fichiers `azure-pipelines.yml`, `*-SETUP.md` correspondent à la phase Azure et sont conservés à titre de référence et de témoignage de l'exploration.

---

## Améliorations envisagées

Pistes pour étendre le projet :

- **GitHub Actions** : pipeline `terraform fmt + validate + trivy config` sur chaque PR (équivalent gratuit du pipeline Azure DevOps).
- **Multi-environnements** : workspace Terraform `dev`/`prod` pour démontrer la séparation des contextes.
- **Backend distant** : remplacer le state local par un MinIO conteneurisé pour reproduire la dynamique d'un backend Azure Storage en environnement local.
- **TLS** : ajout d'un Let's Encrypt (Caddy en frontal au lieu de nginx) pour démontrer le HTTPS automatisé.
- **Observability** : adjonction d'un conteneur Prometheus + Grafana pour surveiller les métriques nginx.

---

## Auteur

**Ness** — Mastère DevOps Infrastructure et Cloud, Sup de Vinci
