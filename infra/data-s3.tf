# S3 Bucket for static data (CSV + Images)
resource "aws_s3_bucket" "data_bucket" {
  bucket = "astro-backend-data-bucket"
}

resource "aws_s3_bucket_versioning" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public read access for data bucket
resource "aws_s3_bucket_policy" "data_bucket_policy" {
  bucket = aws_s3_bucket.data_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.data_bucket.arn}/*"
      }
    ]
  })
}

# Block public ACLs but allow public bucket policies
resource "aws_s3_bucket_public_access_block" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

# CORS configuration for browser access
resource "aws_s3_bucket_cors_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Lifecycle configuration to manage old versions
resource "aws_s3_bucket_lifecycle_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    id     = "manage_versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30 # Alte Versionen nach 30 Tagen löschen
    }
  }
}

# Outputs
output "data_bucket_name" {
  description = "Name des Data S3 Buckets"
  value       = aws_s3_bucket.data_bucket.id
}

output "data_bucket_url" {
  description = "S3 Bucket URL für Data"
  value       = "https://${aws_s3_bucket.data_bucket.bucket}.s3.${data.aws_region.current.name}.amazonaws.com"
}

output "csv_url" {
  description = "Direct S3 URL für autos.csv"
  value       = "https://${aws_s3_bucket.data_bucket.bucket}.s3.${data.aws_region.current.name}.amazonaws.com/autos.csv"
}

output "images_base_url" {
  description = "S3 Base URL für Bilder"
  value       = "https://${aws_s3_bucket.data_bucket.bucket}.s3.${data.aws_region.current.name}.amazonaws.com/images/"
}
