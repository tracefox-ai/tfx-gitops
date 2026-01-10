# Helm Chart Management Makefile

.PHONY: help lint format docs test clean install-tools

# Default target
help: ## Show this help message
	@echo "Helm Chart Management Commands:"
	@echo "==============================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Install required tools
install-tools: ## Install required formatting and linting tools
	@echo "Installing Helm chart tools..."
	@if ! command -v helm &> /dev/null; then \
		echo "Please install Helm first: https://helm.sh/docs/intro/install/"; \
		exit 1; \
	fi
	@if ! command -v yamllint &> /dev/null; then \
		echo "Installing yamllint..."; \
		brew install yamllint; \
	fi
	@if ! command -v helm-docs &> /dev/null; then \
		echo "Installing helm-docs..."; \
		brew install norwoodj/tap/helm-docs; \
	fi
	@echo "✓ All tools installed successfully!"

# Lint all charts
lint: ## Lint all Helm charts
	@echo "Linting Helm charts..."
	@for chart in helm/*/; do \
		if [ -f "$$chart/Chart.yaml" ]; then \
			echo "Linting $$(basename $$chart)..."; \
			helm lint "$$chart"; \
		fi \
	done

# Format and lint charts
format: ## Format and lint all Helm charts
	@./scripts/format-helm.sh

# Generate documentation
docs: ## Generate documentation for all charts
	@echo "Generating documentation..."
	@helm-docs helm/
	@echo "✓ Documentation generated successfully!"

# Test chart templates
test: ## Test Helm chart templates
	@echo "Testing Helm chart templates..."
	@for chart in helm/*/; do \
		if [ -f "$$chart/Chart.yaml" ]; then \
			echo "Testing $$(basename $$chart)..."; \
			helm template test "$$chart" > /dev/null; \
		fi \
	done
	@echo "✓ All template tests passed!"

# YAML lint charts
yaml-lint: ## Run YAML linting on charts
	@echo "YAML linting charts..."
	@if command -v yamllint &> /dev/null; then \
		yamllint -c .yamllint.yml helm/; \
	else \
		echo "yamllint not installed. Run 'make install-tools' first."; \
	fi

# Package charts
package: ## Package all Helm charts
	@echo "Packaging Helm charts..."
	@mkdir -p dist
	@for chart in helm/*/; do \
		if [ -f "$$chart/Chart.yaml" ]; then \
			echo "Packaging $$(basename $$chart)..."; \
			helm package "$$chart" -d dist/; \
		fi \
	done
	@echo "✓ Charts packaged in dist/ directory"

# Clean generated files
clean: ## Clean generated files and packages
	@echo "Cleaning generated files..."
	@rm -rf dist/
	@find helm/ -name "README.md" -delete
	@echo "✓ Cleaned successfully!"

# Dependency update
deps: ## Update chart dependencies
	@echo "Updating chart dependencies..."
	@for chart in helm/*/; do \
		if [ -f "$$chart/Chart.yaml" ]; then \
			echo "Updating dependencies for $$(basename $$chart)..."; \
			helm dependency update "$$chart"; \
		fi \
	done

# Full check (lint + format + test + docs)
check: lint yaml-lint test docs ## Run all checks (lint, format, test, docs)
	@echo "✓ All checks completed successfully!"

# Development setup
setup: install-tools ## Setup development environment
	@echo "Setting up development environment..."
	@chmod +x scripts/format-helm.sh
	@echo "✓ Development environment ready!"