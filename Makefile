.PHONY: help search-api contact-form test-all clean-all

# Default target
help:
	@echo "🚀 Astro Backend CI/CD - Available targets:"
	@echo ""
	@echo "📦 Function operations:"
	@echo "  search-api       - Build and test search API"
	@echo "  contact-form     - Build and test contact form (planned)"
	@echo ""
	@echo "🌍 Global operations:"
	@echo "  test-all         - Test all functions"
	@echo "  clean-all        - Clean all build artifacts"
	@echo "  dev-setup        - Setup development environment"
	@echo "  ci-all           - Run complete CI pipeline"
	@echo ""
	@echo "🏗️ Local infrastructure (optional):"
	@echo "  tf-init          - Initialize Terraform"
	@echo "  plan             - Show Terraform plan"
	@echo "  deploy           - Deploy infrastructure"
	@echo "  destroy          - Destroy infrastructure"
	@echo "  validate         - Validate Terraform configuration"
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

# Clean all build artifacts
clean-all:
	@echo "🧹 Cleaning all build artifacts..."
	cd backend/functions/search-api && make clean
	# cd backend/functions/contact-form && make clean

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

# === LOCAL INFRASTRUCTURE COMMANDS (Optional) ===

# Initialize Terraform (local only)
tf-init:
	@echo "🏗️ Initializing Terraform (local)..."
	cd infra && terraform init

# Show Terraform plan (local only)
plan: tf-init
	@echo "📋 Creating Terraform plan (local)..."
	cd infra && terraform plan

# Deploy infrastructure (local only)
deploy: tf-init
	@echo "🚀 Deploying infrastructure (local)..."
	cd infra && terraform apply
	@echo "Deployment complete!"
	cd infra && terraform output

# Destroy infrastructure (local only)
destroy:
	@echo "💥 Destroying infrastructure (local)..."
	cd infra && terraform destroy

# Validate Terraform configuration (local only)
validate:
	@echo "✅ Validating Terraform configuration (local)..."
	cd infra && terraform validate

# Format Terraform files (local only)
tf-fmt:
	@echo "📝 Formatting Terraform files (local)..."
	cd infra && terraform fmt

# Show infrastructure outputs (local only)
outputs:
	@echo "📊 Infrastructure outputs (local):"
	cd infra && terraform output 