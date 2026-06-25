.PHONY: help lint test install dry-run

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

lint: ## Run shellcheck on all shell scripts
	shellcheck install.sh setup.sh lib/*.sh modules/*.sh

test: ## Run the bats test suite
	bats tests/

install: ## Provision this machine
	./setup.sh

dry-run: ## Show what would run without executing
	./setup.sh --dry-run --yes
