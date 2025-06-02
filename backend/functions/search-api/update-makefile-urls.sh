#!/bin/bash

# Script to update S3 URLs in Makefile from Terraform outputs

set -e

echo "🔍 Getting S3 URLs from Terraform..."

# Change to infra directory
cd ../../../infra

# Get S3 URLs from Terraform output
S3_BASE_URL=$(terraform output -raw data_bucket_url 2>/dev/null)
CSV_URL=$(terraform output -raw csv_url 2>/dev/null)
IMAGES_BASE_URL=$(terraform output -raw images_base_url 2>/dev/null)

if [ -z "$S3_BASE_URL" ]; then
    echo "❌ Could not get S3 URLs from Terraform"
    echo "Make sure Terraform is deployed and working"
    exit 1
fi

# Extract just the domain part for the Makefile placeholders
S3_DOMAIN=$(echo "$S3_BASE_URL" | sed 's|https://||')

echo "✅ Found S3 URLs:"
echo "   Base URL: $S3_BASE_URL"
echo "   CSV URL: $CSV_URL"
echo "   Images URL: $IMAGES_BASE_URL"

# Change back to function directory
cd ../backend/functions/search-api

# Update Makefile with actual S3 URLs
echo "📝 Updating Makefile with S3 URLs..."

# Replace the placeholder with actual domain
sed -i.bak "s|\[CLOUDFRONT_DOMAIN\]|$S3_DOMAIN|g" Makefile

echo "✅ Makefile updated with S3 URLs!"
echo "🌍 CSV URL: $CSV_URL"
echo "🖼️  Images URL: $IMAGES_BASE_URL"

# Remove backup file
rm -f Makefile.bak 