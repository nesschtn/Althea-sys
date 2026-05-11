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
