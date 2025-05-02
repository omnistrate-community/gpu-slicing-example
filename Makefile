SERVICE_NAME=service-test
SERVICE_PLAN=service-test
MAIN_RESOURCE_NAME=web
ENVIRONMENT=Dev
CLOUD_PROVIDER=azure
REGION=eastus2

# Load variables from .env if it exists
ifneq (,$(wildcard .env))
    include .env
    export $(shell sed 's/=.*//' .env)
endif

.PHONY: install-ctl
install-ctl:
	@brew tap omnistrate/tap
	@brew install omnistrate/tap/omnistrate-ctl

.PHONY: upgrade-ctl
upgrade-ctl:
	@brew upgrade omnistrate/tap/omnistrate-ctl
	
.PHONY: login
login:
	@cat ./.omnistrate.password | omnistrate-ctl login --email $(OMNISTRATE_EMAIL) --password-stdin

.PHONY: release
release:
	@omnistrate-ctl build -f compose.yaml --name ${SERVICE_NAME}  --environment ${ENVIRONMENT} --environment-type ${ENVIRONMENT} --release-as-preferred

.PHONY: create
create:
	@omnistrate-ctl instance create --environment ${ENVIRONMENT} --cloud-provider ${CLOUD_PROVIDER} --region ${REGION} --plan ${SERVICE_PLAN} --service ${SERVICE_NAME} --resource ${MAIN_RESOURCE_NAME} 

.PHONY: list
list:
	@omnistrate-ctl instance list --filter=service:${SERVICE_NAME},plan:${SERVICE_PLAN} --output json

.PHONY: delete-all
delete-all:
	@echo "Deleting all instances..."
	@for id in $$(omnistrate-ctl instance list --filter=service:${SERVICE_NAME},plan:${SERVICE_PLAN} --output json | jq -r '.[].instance_id'); do \
		echo "Deleting instance: $$id"; \
		omnistrate-ctl instance delete $$id; \
	done

.PHONY: destroy
destroy: delete-all-wait
	@echo "Destroying service: ${SERVICE_NAME}..."
	@omnistrate-ctl service delete ${SERVICE_NAME}

.PHONY: delete-all-wait
delete-all-wait:
	@echo "Deleting all instances and waiting for completion..."
	@instances_to_delete=$$(omnistrate-ctl instance list --filter=service:${SERVICE_NAME},plan:${SERVICE_PLAN} --output json | jq -r '.[].instance_id'); \
	if [ -n "$$instances_to_delete" ]; then \
		for id in $$instances_to_delete; do \
			echo "Deleting instance: $$id"; \
			omnistrate-ctl instance delete $$id; \
		done; \
		echo "Waiting for instances to be deleted..."; \
		while true; do \
			remaining=$$(omnistrate-ctl instance list --filter=service:${SERVICE_NAME},plan:${SERVICE_PLAN} --output json | jq -r '.[].instance_id'); \
			if [ -z "$$remaining" ]; then \
				echo "All instances deleted successfully"; \
				break; \
			fi; \
			echo "Still waiting for deletion to complete..."; \
			sleep 10; \
		done; \
	else \
		echo "No instances found to delete"; \
	fi