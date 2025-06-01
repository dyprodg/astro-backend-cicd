#!/bin/bash

# 🚀 Search API Development Workflow Example
# This script demonstrates how to work with the new Makefile structure

set -e

echo "🚗 Search API Development Workflow"
echo "=================================="
echo ""

# Option 1: Work directly in the function directory (Recommended)
echo "📂 Option 1: Working in function directory"
echo "cd backend/functions/search-api"
echo ""

echo "🔧 Available commands in function directory:"
echo "make help          # Show all available targets"
echo "make deps          # Install dependencies"
echo "make test          # Run tests"
echo "make test-cover    # Run tests with coverage"
echo "make build         # Build for Lambda (ARM64)"
echo "make build-local   # Build for local testing"
echo "make deploy        # Deploy with Terraform"
echo "make update-lambda # Quick Lambda update"
echo ""

# Option 2: Work from root directory
echo "📂 Option 2: Working from root directory"
echo ""

echo "🌍 Global commands from root:"
echo "make help          # Show global targets"
echo "make search-api    # Build and test search API"
echo "make test-all      # Test all functions"
echo "make deploy-all    # Deploy all infrastructure"
echo "make tf-init       # Initialize Terraform"
echo ""

# Typical development workflow
echo "🔄 Typical Development Workflow:"
echo "==============================="
echo ""

echo "1. Setup development environment:"
echo "   cd backend/functions/search-api"
echo "   make deps"
echo ""

echo "2. Make your changes..."
echo ""

echo "3. Test your changes:"
echo "   make test"
echo "   # or with coverage:"
echo "   make test-cover"
echo ""

echo "4. Build and validate:"
echo "   make build"
echo "   make fmt"
echo "   make lint"
echo ""

echo "5. Deploy (choose one):"
echo "   # Quick Lambda update:"
echo "   make update-lambda"
echo "   # Full deployment:"
echo "   make deploy"
echo "   # Or from root:"
echo "   cd ../../../"
echo "   make deploy-function FUNCTION=search-api"
echo ""

echo "6. Test deployment:"
echo "   cd backend/functions/search-api"
echo "   make test-api"
echo ""

# Show directory structure
echo "📁 New Directory Structure:"
echo "=========================="
echo ""
echo "├── Makefile                              # Global operations"
echo "├── backend/"
echo "│   └── functions/"
echo "│       ├── search-api/"
echo "│       │   ├── Makefile                 # Function-specific operations"
echo "│       │   ├── main.go"
echo "│       │   ├── main_test.go"
echo "│       │   ├── go.mod"
echo "│       │   └── README.md"
echo "│       └── contact-form/"
echo "│           └── (future Makefile here)"
echo "├── infra/"
echo "│   ├── main.tf"
echo "│   └── search-api.tf"
echo "└── .github/"
echo "    └── workflows/"
echo "        └── search-api-deploy.yml"
echo ""

echo "✅ Benefits of this structure:"
echo "• Each function is self-contained"
echo "• Simple paths (no more ../../../)"
echo "• Easy to work on individual functions"
echo "• Scalable for multiple functions"
echo "• Clear separation of concerns"
echo ""

echo "🚀 Ready to start developing!" 