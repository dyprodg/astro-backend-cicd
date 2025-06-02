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

# CloudFront Origin Access Control for data bucket
resource "aws_cloudfront_origin_access_control" "data_bucket" {
  name                              = "astro-data-bucket-oac"
  description                       = "Origin Access Control for Data Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Updated bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "data_bucket_policy" {
  bucket = aws_s3_bucket.data_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.data_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.data_bucket.arn
          }
        }
      }
    ]
  })
}

# Remove public access blocks since we're using CloudFront
resource "aws_s3_bucket_public_access_block" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

# CORS configuration - Allow access from CloudFront domains
resource "aws_s3_bucket_cors_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = [
      "http://localhost:*",
      "https://d3vwo1jrxlfg1i.cloudfront.net",
      "*"
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# CloudFront Distribution for data bucket
resource "aws_cloudfront_distribution" "data_bucket" {
  origin {
    domain_name              = aws_s3_bucket.data_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.data_bucket.id
    origin_id                = "S3-${aws_s3_bucket.data_bucket.bucket}"
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront distribution for data bucket (CSV + Images)"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.data_bucket.bucket}"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400    # 1 day cache for images
    max_ttl                = 31536000 # 1 year max
    compress               = true
  }

  # Longer cache for images
  ordered_cache_behavior {
    path_pattern     = "/images/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.data_bucket.bucket}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 86400    # 1 day
    default_ttl            = 2592000  # 30 days
    max_ttl                = 31536000 # 1 year
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Shorter cache for CSV (data might change)
  ordered_cache_behavior {
    path_pattern     = "*.csv"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.data_bucket.bucket}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600  # 1 hour cache for CSV
    max_ttl                = 86400 # 1 day max
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100" # Use only North America and Europe edge locations

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "astro-data-distribution"
    Environment = "production"
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

output "data_bucket_cloudfront_url" {
  description = "CloudFront URL für Data Bucket"
  value       = "https://${aws_cloudfront_distribution.data_bucket.domain_name}"
}

output "data_bucket_url" {
  description = "S3 Bucket URL für Data (Legacy - use CloudFront instead)"
  value       = "https://${aws_s3_bucket.data_bucket.bucket}.s3.${data.aws_region.current.name}.amazonaws.com"
}

output "csv_url" {
  description = "CloudFront URL für autos.csv"
  value       = "https://${aws_cloudfront_distribution.data_bucket.domain_name}/autos.csv"
}

output "images_base_url" {
  description = "CloudFront Base URL für Bilder"
  value       = "https://${aws_cloudfront_distribution.data_bucket.domain_name}/images/"
}

# Additional data source needed for region
data "aws_region" "current" {}
