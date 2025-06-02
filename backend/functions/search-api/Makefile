.PHONY: help build test deploy clean deps fmt lint

# Default target
help:
	@echo "🚗 Search API - Available targets:"
	@echo ""
	@echo "🏗️ Build & Deploy:"
	@echo "  build         - Build Lambda binary for ARM64 (downloads CSV from S3)"
	@echo "  build-local   - Build for local testing (x86_64)"
	@echo "  zip           - Create deployment ZIP"
	@echo "  update-lambda - Update Lambda function code"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  test          - Run all tests"
	@echo "  test-cover    - Run tests with coverage"
	@echo "  test-api      - Test deployed API endpoints"
	@echo ""
	@echo "🔧 Development:"
	@echo "  deps          - Install/update dependencies"
	@echo "  fmt           - Format Go code"
	@echo "  lint          - Run linter"
	@echo "  clean         - Clean build artifacts"
	@echo ""
	@echo "📊 Data Management:"
	@echo "  download-csv  - Download CSV from S3 data bucket"
	@echo "  upload-csv    - Upload CSV to S3 data bucket"
	@echo "  upload-image  - Upload image (usage: make upload-image FILE=path/to/image.jpg)"
	@echo ""
	@echo "🏗️ Local infrastructure (optional):"
	@echo "  deploy        - Deploy with Terraform (local)"
	@echo "  plan          - Show Terraform plan (local)"
	@echo ""
	@echo "🛠️ Utilities:"
	@echo "  logs          - Show Lambda logs"
	@echo "  upload-coverage - Upload coverage to S3"

# Download CSV from S3 Data Bucket
download-csv:
	@echo "Downloading CSV from S3 Data Bucket..."
	@if aws s3 ls s3://astro-backend-data-bucket/autos.csv > /dev/null 2>&1; then \
		echo "Downloading autos.csv from S3..."; \
		aws s3 cp s3://astro-backend-data-bucket/autos.csv ./autos.csv; \
		echo "CSV downloaded successfully!"; \
	else \
		echo "⚠️  CSV not found in S3, using local version"; \
		if [ ! -f ./autos.csv ]; then \
			echo "❌ No local CSV found either! Please upload autos.csv to S3 first."; \
			exit 1; \
		fi; \
	fi

# Build the Lambda binary for ARM64 Linux
build: download-csv
	@echo "Building search API for Lambda (Linux ARM64)..."
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-s -w" -o bootstrap main.go

# Build for local testing (native macOS)
build-local:
	@echo "Building search API for local testing (native macOS)..."
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

# Update Lambda function code (main deployment method)
update-lambda: zip
	@echo "Updating Lambda function..."
	aws lambda update-function-code \
		--function-name search-api \
		--zip-file fileb://search-api.zip
	@echo "Lambda function updated!"

# Show logs from Lambda function
logs:
	@echo "Showing recent Lambda logs..."
	aws logs tail /aws/lambda/search-api --follow

# Test deployed API endpoints
test-api:
	@echo "Testing deployed API endpoints..."
	@echo "1. Getting search options..."
	@curl -s "https://brlsb82kdc.execute-api.eu-central-1.amazonaws.com/prod/search/options" | jq .
	@echo "\n2. Testing search with BMW query..."
	@curl -s -X POST "https://brlsb82kdc.execute-api.eu-central-1.amazonaws.com/prod/search" \
		-H "Content-Type: application/json" \
		-d '{"query": "BMW", "limit": 2}' | jq .

# Quick development workflow
dev: deps fmt lint test
	@echo "Development checks complete!"

# Complete CI/CD workflow
ci: deps fmt lint test-cover build
	@echo "CI/CD pipeline complete!"

# === LOCAL INFRASTRUCTURE COMMANDS (Optional) ===

# Initialize Terraform (local only)
tf-init:
	@echo "Initializing Terraform (local)..."
	cd ../../../infra && terraform init

# Show Terraform plan (local only)
plan: tf-init
	@echo "Creating Terraform plan (local)..."
	cd ../../../infra && terraform plan

# Deploy with Terraform (local only)
deploy: tf-init
	@echo "Deploying with Terraform (local)..."
	cd ../../../infra && terraform apply
	@echo "Getting API endpoints..."
	cd ../../../infra && terraform output

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
		"https://brlsb82kdc.execute-api.eu-central-1.amazonaws.com/prod/search"

# Upload coverage to S3
upload-coverage:
	@echo "Uploading coverage to S3..."
	aws s3 cp coverage.html s3://your-bucket-name/coverage.html
	@echo "Coverage uploaded to S3!"

# Upload CSV to S3 Data Bucket
upload-csv:
	@echo "Uploading CSV to S3 Data Bucket..."
	@if [ ! -f ./autos.csv ]; then \
		echo "❌ autos.csv not found in current directory"; \
		exit 1; \
	fi
	aws s3 cp ./autos.csv s3://astro-backend-data-bucket/autos.csv
	@echo "✅ CSV uploaded to S3!"
	@echo "Public URL: https://astro-backend-data-bucket.s3.eu-central-1.amazonaws.com/autos.csv"

# Upload images to S3 Data Bucket
upload-image:
	@if [ -z "$(FILE)" ]; then \
		echo "❌ Usage: make upload-image FILE=path/to/image.jpg"; \
		exit 1; \
	fi
	@if [ ! -f "$(FILE)" ]; then \
		echo "❌ File $(FILE) not found"; \
		exit 1; \
	fi
	@FILENAME=$$(basename "$(FILE)"); \
	aws s3 cp "$(FILE)" s3://astro-backend-data-bucket/images/$$FILENAME; \
	echo "✅ Image uploaded to S3!"; \
	echo "Public URL: https://astro-backend-data-bucket.s3.eu-central-1.amazonaws.com/images/$$FILENAME" 