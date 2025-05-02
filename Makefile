SERVICE_NAME=gpu-slicing-example
SERVICE_PLAN=gpu-slicing-example
MAIN_RESOURCE_NAME=gpuinfo
ENVIRONMENT=Dev
CLOUD_PROVIDER=aws
REGION=ap-south-1
INSTANCE_TYPE=g4dn.xlarge

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
	@omnistrate-ctl instance create --environment ${ENVIRONMENT} --cloud-provider ${CLOUD_PROVIDER} --region ${REGION} --plan ${SERVICE_PLAN} --service ${SERVICE_NAME} --resource ${MAIN_RESOURCE_NAME} --param '{"instanceType":"${INSTANCE_TYPE}"}'

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

# Detect OS and GPU
OS := $(shell uname)
HAS_NVIDIA_GPU := $(shell command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=gpu_name --format=csv,noheader,nounits 2>/dev/null | wc -l)

.PHONY: build
build:
	docker build -t gpu-slicing-app .

.PHONY: run
run:
ifeq ($(OS),Darwin)
	@echo "Running on macOS without GPU support"
	docker run -p 5000:5000 gpu-slicing-app
else
	@if [ "$(HAS_NVIDIA_GPU)" -gt "0" ]; then \
		echo "Running with NVIDIA GPU support ($(HAS_NVIDIA_GPU) GPUs detected)"; \
		docker run --gpus all -p 5000:5000 gpu-slicing-app; \
	else \
		echo "Running without GPU support - no NVIDIA GPUs detected"; \
		docker run -p 5000:5000 gpu-slicing-app; \
	fi
endif

.PHONY: dev
dev: build run
