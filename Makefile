.DEFAULT_GOAL := help

STACK        ?= sandbox1
AUTO_APPROVE ?= false
CONFIRM      ?=

TG  ?= terragrunt
TF  ?= terraform
AWS ?= aws

STACK_PATH_sandbox1 := live/nonprod/sandbox1

STACK_DIR := $(STACK_PATH_$(STACK))

APPROVE_FLAG :=
ifeq ($(AUTO_APPROVE),true)
APPROVE_FLAG := --terragrunt-non-interactive -auto-approve
endif

.PHONY: help
help: ## Show available targets
	@printf '%s\n' \
		'AVRE AWS Deployment' \
		'' \
		'Current: STACK=$(STACK) DIR=$(if $(STACK_DIR),$(STACK_DIR),<unknown stack>)' \
		'' \
		'Workflow' \
		'  make plan                 Run terragrunt plan for STACK' \
		'  make apply                Run terragrunt apply for STACK' \
		'  make output               Show outputs for STACK' \
		'  make destroy              Destroy the deployment (requires CONFIRM=yes)'

.PHONY: check-tools
check-tools: ## Check CLI requirements and AWS authentication
	@echo "Checking required CLI tools..."
	@command -v $(TF) >/dev/null 2>&1 || { echo "ERROR: terraform is not installed"; exit 1; }
	@command -v $(TG) >/dev/null 2>&1 || { echo "ERROR: terragrunt is not installed"; exit 1; }
	@command -v $(AWS) >/dev/null 2>&1 || { echo "ERROR: aws CLI is not installed"; exit 1; }
	@echo "Checking AWS caller identity..."
	@$(AWS) sts get-caller-identity >/dev/null || { echo "ERROR: AWS CLI is not authenticated."; exit 1; }
	@echo "All tools present and authenticated."

.PHONY: plan
plan: check-stack ## Run terragrunt plan
	cd $(STACK_DIR) && $(TG) plan

.PHONY: apply
apply: check-stack ## Run terragrunt apply
	cd $(STACK_DIR) && $(TG) apply $(APPROVE_FLAG)

.PHONY: output
output: check-stack ## Show terragrunt outputs
	cd $(STACK_DIR) && $(TG) output

.PHONY: destroy
destroy: check-stack ## Destroy deployment (requires CONFIRM=yes)
ifneq ($(CONFIRM),yes)
	$(error Destroy safety check failed. Run 'make destroy STACK=$(STACK) CONFIRM=yes')
endif
	cd $(STACK_DIR) && $(TG) destroy $(APPROVE_FLAG)

.PHONY: check-stack
check-stack:
ifndef STACK_DIR
	$(error Invalid STACK="$(STACK)". Supported values: sandbox1)
endif
