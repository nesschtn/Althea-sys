# =============================================================================
# Althea-sys - Makefile (deploiement local Docker)
# =============================================================================

.DEFAULT_GOAL := help

TF_DIR      := terraform
ANSIBLE_DIR := ansible

.PHONY: help up down restart status logs scan plan apply configure clean

help: ## Affiche cette aide
	@echo "Cibles disponibles :"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: apply configure ## Deploie tout (Terraform + Ansible)
	@echo ""
	@echo "==> Deploiement termine !"
	@echo "    Ouvre http://localhost:8080 dans ton navigateur."

plan: ## Affiche le plan Terraform sans appliquer
	cd $(TF_DIR) && terraform init -upgrade && terraform plan

apply: ## Applique le plan Terraform (cree les conteneurs)
	cd $(TF_DIR) && terraform init -upgrade && terraform apply -auto-approve
	@echo "==> Generation de l'inventaire Ansible..."
	cd $(TF_DIR) && terraform output -raw ansible_inventory > ../$(ANSIBLE_DIR)/inventory.ini
	@echo "==> Inventaire genere :"
	@cat $(ANSIBLE_DIR)/inventory.ini

configure: ## Lance Ansible sur les conteneurs
	cd $(ANSIBLE_DIR) && ansible-playbook playbook.yml

scan: ## Scan securite Trivy (IaC + images)
	@echo "==> Scan IaC (Terraform)..."
	-trivy config $(TF_DIR)
	@echo ""
	@echo "==> Scan image nginx..."
	-trivy image --severity HIGH,CRITICAL nginx:1.27-alpine

status: ## Affiche l'etat des conteneurs
	docker ps --filter "label=project=althea-sys" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

logs: ## Affiche les logs des conteneurs
	docker logs althea-dev-proxy --tail 20
	@echo ""
	docker logs althea-dev-web --tail 20

restart: ## Redemarre les conteneurs
	docker restart althea-dev-proxy althea-dev-web

down: ## Detruit tout (Terraform destroy)
	cd $(TF_DIR) && terraform destroy -auto-approve
	rm -f $(ANSIBLE_DIR)/inventory.ini

clean: down ## Detruit + nettoie les fichiers Terraform locaux
	rm -rf $(TF_DIR)/.terraform $(TF_DIR)/terraform.tfstate*
	rm -f $(ANSIBLE_DIR)/inventory.ini
