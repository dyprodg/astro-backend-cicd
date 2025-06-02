.PHONY: help build clean deps test fmt lint test-cover update-lambda

# Variables
FUNCTION_NAME=contact-form
GOOS=linux
GOARCH=arm64
GO=go
GOLANGCI_LINT=golangci-lint

# Show help
help:
	@echo "Contact Form Lambda - Available Commands:"
	@echo ""
	@echo "  make deps         - Install Go dependencies"
	@echo "  make test         - Run tests"
	@echo "  make test-cover   - Run tests with coverage report"
	@echo "  make fmt          - Format Go code"
	@echo "  make lint         - Run linter"
	@echo "  make build        - Build Lambda function"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make update-lambda - Deploy to AWS (requires AWS CLI)"
	@echo "  make package      - Create deployment package"
	@echo ""
	@echo "Getting started:"
	@echo "  1. make deps      - Install dependencies first"
	@echo "  2. make test      - Run tests to verify setup"
	@echo "  3. make build     - Build the Lambda"

# Build the Lambda function
build: clean
	@echo "Building Lambda function..."
	GOOS=$(GOOS) GOARCH=$(GOARCH) CGO_ENABLED=0 $(GO) build -ldflags="-s -w" -o bootstrap main.go
	@echo "Creating deployment package..."
	zip -j contact-form.zip bootstrap
	@echo "Build complete: contact-form.zip"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f bootstrap contact-form.zip
	rm -f coverage.out coverage.html

# Install dependencies
deps:
	@echo "Installing dependencies..."
	$(GO) get -u ./...
	$(GO) mod tidy
	$(GO) mod download

# Run tests
test:
	@echo "Running tests..."
	$(GO) test -v ./...

# Run tests with coverage
test-cover:
	@echo "Running tests with coverage..."
	$(GO) test -v -coverprofile=coverage.out ./...
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Format code
fmt:
	@echo "Formatting code..."
	$(GO) fmt ./...

# Run linter
lint:
	@echo "Running linter..."
	@if ! command -v golangci-lint > /dev/null; then \
		echo "Installing golangci-lint..."; \
		mkdir -p ./bin; \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b ./bin; \
		export PATH="$$PWD/bin:$$PATH"; \
	fi
	@if command -v golangci-lint > /dev/null; then \
		golangci-lint run; \
	elif [ -f ./bin/golangci-lint ]; then \
		./bin/golangci-lint run; \
	else \
		echo "Warning: golangci-lint not found, skipping linting"; \
	fi

# Update Lambda function (requires AWS CLI configured)
update-lambda: build
	@echo "Updating Lambda function $(FUNCTION_NAME)..."
	aws lambda update-function-code \
		--function-name $(FUNCTION_NAME) \
		--zip-file fileb://contact-form.zip \
		--region $(AWS_REGION)
	@echo "Lambda function updated successfully!"

# Create deployment package for CI/CD
package: build
	@echo "Deployment package created: contact-form.zip" 