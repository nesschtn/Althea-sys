# Pipeline Azure DevOps — Althea-sys (DEV)

Ce pipeline déploie l'infrastructure et configure la VM web du projet Althea-sys, en récupérant le code mirroré depuis GitHub.

## Vue d'ensemble des stages

| # | Stage | Rôle |
|---|---|---|
| 1 | **Validate** | `terraform fmt` + `validate`, `ansible-lint` |
| 2 | **SecurityScan** | `tfsec` sur le code Terraform (rapport JUnit publié) |
| 3 | **Plan** | `terraform init` (backend Azure Storage) + `plan`, artefact `tfplan` |
| 4 | **Apply** | `terraform apply` avec **approbation manuelle** via environnement `dev` |
| 5 | **Configure** | Génération d'inventaire depuis les outputs Terraform + `ansible-playbook` |
| 6 | **SmokeTest** | `curl` sur l'URL publique pour valider le déploiement |

## Pré-requis (à faire une seule fois côté Azure DevOps)

### 1. Backend Terraform (Storage Account)

Crée le storage account qui stockera l'état Terraform. Depuis Cloud Shell ou local :

```bash
az group create -n rg-tfstate-althea -l francecentral
az storage account create -g rg-tfstate-althea -n satfstatealtheaXXXXX -l francecentral --sku Standard_LRS
az storage container create --account-name satfstatealtheaXXXXX -n tfstate
```

Mets à jour les variables `TF_BACKEND_*` dans le YAML avec les vrais noms.

### 2. Service Connection Azure

Project Settings → **Service connections** → **New service connection** → **Azure Resource Manager** → **Workload Identity Federation (automatic)**. Nomme-la `sc-azure-dev` (ou change la variable `AZURE_SERVICE_CONNECTION` dans le YAML).

Le SP créé doit avoir les droits `Contributor` sur la subscription cible **et** un accès au storage account du tfstate (`Storage Blob Data Contributor`).

### 3. Environnement `dev` (pour l'approbation manuelle)

Pipelines → **Environments** → **New environment** → nom `dev` → **Approvals and checks** → ajoute toi-même comme approbateur. Sans ça, le stage Apply est bloqué indéfiniment.

### 4. Variables et secrets du pipeline

Dans le pipeline → **Variables** (ou une Variable Group liée) :

| Nom | Type | Valeur |
|---|---|---|
| `SSH_PUBLIC_KEY` | secret | Contenu public de ta clé SSH (`ssh-rsa AAAA...`) |
| `ADMIN_USERNAME` | normal | `azureuser` (ou ce que tu mets dans `terraform.tfvars`) |

### 5. Secure File — clé SSH privée

Pipelines → **Library** → **Secure files** → **+ Secure file** → upload ta clé privée SSH sous le nom `althea-ssh-key`. Le pipeline la télécharge automatiquement au stage Configure.

> ⚠️ La clé privée ne doit jamais être commitée. C'est exactement à ça que sert Secure Files.

## Premier run

1. Pousse le pipeline sur la branche `main` côté GitHub.
2. Le mirror le propage sur Azure DevOps (cf. `MIRROR-SETUP.md`).
3. Pipelines → **New pipeline** → **Azure Repos Git** → sélectionne le repo mirroré → Azure DevOps détecte le `azure-pipelines.yml`.
4. Lance manuellement le premier run.
5. À la fin du stage Plan, vérifie le plan dans les logs, puis valide l'approbation pour déclencher Apply.

## Conseils pour ton portfolio

- Le `--soft-fail` sur `tfsec` est volontaire en dev : tu vois les findings sans bloquer. Pour un stage `prod`, on le passerait bloquant — c'est exactement le genre de progression "shift-left" qui se commente bien en soutenance.
- Si tu ajoutes plus tard une étape de build d'image Docker, c'est là qu'on insérera **Trivy** entre le build et le push vers ACR.
- Le pattern "outputs Terraform → inventaire Ansible dynamique" est applicable tel quel pour un futur AKS : il suffira de remplacer le playbook par des manifests Helm/kubectl et de cibler le cluster au lieu de la VM.

## Dépannage

- **`Backend initialization required`** au stage Plan → le storage account du tfstate n'existe pas ou le SP n'a pas les droits dessus.
- **Stage Apply bloqué en attente** → personne n'a approuvé dans l'environnement `dev`. Va dans Environments → dev → Approve.
- **`Permission denied (publickey)`** au stage Configure → mauvaise clé dans Secure Files, ou la clé publique du `SSH_PUBLIC_KEY` ne correspond pas à la privée uploadée.
- **Smoke test KO** → ouvre l'URL manuellement. Souvent cloud-init pas encore terminé : augmente le `for i in {1..10}` du stage SmokeTest.
