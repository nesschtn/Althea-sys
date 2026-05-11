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
