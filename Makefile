.PHONY: help search-api contact-form deploy-all test-all clean-all tf-init plan deploy destroy

# Default target
help:
	@echo "🚀 Astro Backend CI/CD - Available targets:"
	@echo ""
	@echo "📦 Function-specific operations:"
	@echo "  search-api       - Build and test search API"
	@echo "  contact-form     - Build and test contact form"
	@echo ""
	@echo "🌍 Global operations:"
	@echo "  test-all         - Test all functions"
	@echo "  deploy-all       - Deploy all infrastructure"
	@echo "  clean-all        - Clean all build artifacts"
	@echo ""
	@echo "🏗️ Infrastructure operations:"
	@echo "  tf-init          - Initialize Terraform"
	@echo "  plan             - Show Terraform plan"
	@echo "  deploy           - Deploy infrastructure"
	@echo "  destroy          - Destroy infrastructure"
	@echo "  validate         - Validate Terraform configuration"
	@echo "  tf-fmt           - Format Terraform files"
	@echo ""
	@echo "💡 Function-specific commands:"
	@echo "  cd backend/functions/search-api && make help"
	@echo "  cd backend/functions/contact-form && make help"

# Search API operations
search-api:
	@echo "🚗 Building and testing Search API..."
	cd backend/functions/search-api && make ci

# Contact Form operations (placeholder for future implementation)
contact-form:
	@echo "📧 Contact Form operations not yet implemented"
	@echo "Future: cd backend/functions/contact-form && make ci"

# Test all functions
test-all:
	@echo "🧪 Testing all functions..."
	cd backend/functions/search-api && make test
	# cd backend/functions/contact-form && make test

# Deploy all infrastructure
deploy-all: tf-init
	@echo "🚀 Deploying all infrastructure..."
	cd infra && terraform apply -auto-approve
	@echo "Deployment complete!"
	cd infra && terraform output

# Clean all build artifacts
clean-all:
	@echo "🧹 Cleaning all build artifacts..."
	cd backend/functions/search-api && make clean
	# cd backend/functions/contact-form && make clean

# Initialize Terraform
tf-init:
	@echo "🏗️ Initializing Terraform..."
	cd infra && terraform init

# Show Terraform plan
plan: tf-init
	@echo "📋 Creating Terraform plan..."
	cd infra && terraform plan

# Deploy infrastructure
deploy: tf-init
	@echo "🚀 Deploying infrastructure..."
	cd infra && terraform apply -auto-approve
	@echo "Deployment complete!"
	cd infra && terraform output

# Destroy infrastructure
destroy:
	@echo "💥 Destroying infrastructure..."
	cd infra && terraform destroy -auto-approve

# Validate Terraform configuration
validate:
	@echo "✅ Validating Terraform configuration..."
	cd infra && terraform validate

# Format Terraform files
tf-fmt:
	@echo "📝 Formatting Terraform files..."
	cd infra && terraform fmt

# Show infrastructure outputs
outputs:
	@echo "📊 Infrastructure outputs:"
	cd infra && terraform output

# Quick development setup
dev-setup:
	@echo "🛠️ Setting up development environment..."
	cd backend/functions/search-api && make deps
	# cd backend/functions/contact-form && make deps

# CI/CD pipeline for all functions
ci-all:
	@echo "🔄 Running CI/CD for all functions..."
	cd backend/functions/search-api && make ci
	# cd backend/functions/contact-form && make ci

# Quick local test
test-local:
	@echo "🧪 Running local tests..."
	$(MAKE) test-all

# Deploy specific function (requires FUNCTION parameter)
deploy-function:
	@if [ -z "$(FUNCTION)" ]; then \
		echo "❌ Error: FUNCTION parameter is required"; \
		echo "Usage: make deploy-function FUNCTION=search-api"; \
		exit 1; \
	fi
	@echo "🚀 Deploying $(FUNCTION)..."
	cd backend/functions/$(FUNCTION) && make deploy 