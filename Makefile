SHELL:=bash

PIPELINE_ID = $(shell whoami | awk -F '.' '{print substr($$1,1,3) "-" substr($$2,1,3)}')

default: help

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: test
test: ## Build, test, and destroy all scenarios with Kitchen Terraform
	@make setup
	@./run-kitchen.sh --pipeline-id ${PIPELINE_ID} --action test --args "--destroy=always"
	@make delete-test-dir

.PHONY: build
build: ## Build all scenarios with Kitchen Terraform
	@make setup
	@./run-kitchen.sh --pipeline-id ${PIPELINE_ID} --action converge

.PHONY: verify
verify: ## Verify all scenarios with Kitchen Terraform
	@make setup
	@make copy-test-dir # test directory is copied and deleted each time so that edits to tests are applied
	@./run-kitchen.sh --pipeline-id ${PIPELINE_ID} --action verify || true # so that it still destroys
	@make delete-test-dir

.PHONY: destroy
destroy: ## Destroy all scenarios with Kitchen Terraform
	@./run-kitchen.sh --pipeline-id ${PIPELINE_ID} --action destroy
	@make teardown

.PHONY: debug
debug: ## Debug all scenarios with Kitchen Terraform
	@make setup
	@./run-kitchen.sh --pipeline-id ${PIPELINE_ID} --action debug

.PHONY: copy-test-dir
copy-test-dir:
	@cp -r test/integration/internal test/integration/internal-${PIPELINE_ID} # TODO add external

.PHONY: delete-test-dir
delete-test-dir:
	@printf "\nDeleting test/integration/internal-${PIPELINE_ID}\n"
	@rm -rf test/integration/internal-${PIPELINE_ID}

.DELETE_ON_ERROR:
setup:
	@#make bootstrap
	@make copy-test-dir
	echo "this file signals that local setup is complete" > setup

.DELETE_ON_ERROR:
teardown:
	rm setup || true
	@make delete-test-dir
