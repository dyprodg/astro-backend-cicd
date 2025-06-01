.PHONY: help build test deploy clean deps fmt lint

# Default target
help:
	@echo "🚗 Search API - Available targets:"
	@echo "  build       - Build Lambda binary for ARM64"
	@echo "  build-local - Build for local testing (x86_64)"
	@echo "  test        - Run all tests"
	@echo "  test-cover  - Run tests with coverage"
	@echo "  deps        - Install/update dependencies"
	@echo "  fmt         - Format Go code"
	@echo "  lint        - Run linter"
	@echo "  clean       - Clean build artifacts"
	@echo "  zip         - Create deployment ZIP"
	@echo "  deploy      - Deploy with Terraform"
	@echo "  plan        - Show Terraform plan"

# Build the Lambda binary for ARM64
build:
	@echo "Building search API for ARM64..."
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o bootstrap main.go

# Build for local testing (x86_64)
build-local:
	@echo "Building search API for local testing..."
	go build -o main main.go

# Run tests
test:
	@echo "Running tests..."
	go test -v

# Run tests with coverage
test-cover:
	@echo "Running tests with coverage..."
	go test -v -cover -coverprofile=coverage.out
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Install/update dependencies
deps:
	@echo "Installing dependencies..."
	go mod tidy
	go mod download

# Format Go code
fmt:
	@echo "Formatting Go code..."
	go fmt ./...

# Run linter
lint:
	@echo "Running linter..."
	go vet ./...

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f main
	rm -f bootstrap
	rm -f search-api.zip
	rm -f coverage.out
	rm -f coverage.html

# Create deployment ZIP
zip: build
	@echo "Creating deployment ZIP..."
	zip -r search-api.zip bootstrap

# Quick development workflow
dev: deps fmt lint test
	@echo "Development checks complete!"

# Complete CI/CD workflow
ci: deps fmt lint test-cover build
	@echo "CI/CD pipeline complete!"

# Initialize Terraform (from function directory)
tf-init:
	@echo "Initializing Terraform..."
	cd ../../../infra && terraform init

# Show Terraform plan
plan: build tf-init
	@echo "Creating Terraform plan..."
	cd ../../../infra && terraform plan

# Deploy with Terraform
deploy: build tf-init
	@echo "Deploying with Terraform..."
	cd ../../../infra && terraform apply -auto-approve
	@echo "Deployment complete!"
	@echo "Getting API endpoints..."
	cd ../../../infra && terraform output

# Update Lambda function code only (faster than full deploy)
update-lambda: build
	@echo "Updating Lambda function..."
	zip -r search-api.zip bootstrap
	aws lambda update-function-code \
		--function-name search-api \
		--zip-file fileb://search-api.zip
	@echo "Lambda function updated!"

# Show logs from Lambda function
logs:
	@echo "Showing recent Lambda logs..."
	aws logs tail /aws/lambda/search-api --follow

# Test API endpoints (requires jq and deployed infrastructure)
test-api:
	@echo "Testing API endpoints..."
	@echo "1. Getting search options..."
	@curl -s $$(cd ../../../infra && terraform output -raw search_options_endpoint) | jq .
	@echo "\n2. Testing search with BMW query..."
	@curl -s -X POST $$(cd ../../../infra && terraform output -raw search_endpoint) \
		-H "Content-Type: application/json" \
		-d '{"query": "BMW", "limit": 2}' | jq .

# Install development tools
install-tools:
	@echo "Installing development tools..."
	go install golang.org/x/tools/cmd/goimports@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Run comprehensive linting
lint-comprehensive:
	@echo "Running comprehensive linting..."
	golangci-lint run

# Load test the API (requires hey tool)
load-test:
	@echo "Running load test..."
	hey -n 100 -c 10 -m POST \
		-H "Content-Type: application/json" \
		-d '{"query": "BMW"}' \
		$$(cd ../../../infra && terraform output -raw search_endpoint) 