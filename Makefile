.PHONY: help lint test test-tls build publish clean install deploy common controllers brokers monitoring kafka-ui topics acls scram health rolling-restart upgrade analysis

INVENTORY ?= examples/inventory/hosts.yml
PLAYBOOK_DIR := playbooks
ANSIBLE_OPTS ?=

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# --- Development ---

lint: ## Lint all playbooks and roles
	yamllint .
	ansible-lint

test: ## Run Molecule default scenario
	molecule test -s default

test-tls: ## Run Molecule kraft-tls scenario
	molecule test -s kraft-tls

# --- Build & Publish ---

build: ## Build Ansible Galaxy collection tarball
	ansible-galaxy collection build --force

publish: build ## Publish collection to Ansible Galaxy (requires GALAXY_TOKEN)
	ansible-galaxy collection publish osodevops-kafka_platform-*.tar.gz --api-key $(GALAXY_TOKEN)

clean: ## Remove build artifacts
	rm -f osodevops-kafka_platform-*.tar.gz
	rm -rf .molecule/

# --- Deployment ---

install: ## Install Ansible Galaxy requirements
	ansible-galaxy collection install -r requirements.yml

deploy: ## Full cluster deployment (site.yml)
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/site.yml $(ANSIBLE_OPTS)

common: ## Run common role only (OS prep)
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/common.yml $(ANSIBLE_OPTS)

controllers: ## Deploy KRaft controllers
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/kafka_controller.yml $(ANSIBLE_OPTS)

brokers: ## Deploy Kafka brokers
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/kafka_broker.yml $(ANSIBLE_OPTS)

monitoring: ## Deploy Prometheus + Grafana
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/monitoring.yml $(ANSIBLE_OPTS)

kafka-ui: ## Deploy Kafka UI only
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/site.yml --tags kafka_ui $(ANSIBLE_OPTS)

topics: ## Create Kafka topics
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/create_topics.yml $(ANSIBLE_OPTS)

acls: ## Provision Kafka ACLs
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/create_acls.yml $(ANSIBLE_OPTS)

scram: ## Create SCRAM users
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/create_scram_users.yml $(ANSIBLE_OPTS)

health: ## Run health checks
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/health_check.yml $(ANSIBLE_OPTS)

rolling-restart: ## Rolling restart of cluster
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/rolling_restart.yml $(ANSIBLE_OPTS)

upgrade: ## Upgrade Kafka version
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/upgrade.yml $(ANSIBLE_OPTS)

analysis: ## Analyse Kafka topic configuration (read-only)
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/analysis.yml $(ANSIBLE_OPTS)
