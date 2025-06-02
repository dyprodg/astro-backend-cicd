resource "aws_s3_bucket" "frontend" {
  bucket = "astro-frontend-bucket"
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_s3_policy.json
}

data "aws_iam_policy_document" "frontend_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    effect = "Allow"
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "astro-frontend-oac"
  description                       = "Origin Access Control for Astro Frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
    origin_id                = "S3-${aws_s3_bucket.frontend.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for Astro frontend"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 60  # Reduced from 3600 to 60 seconds (1 minute)
    max_ttl                = 300 # Reduced from 86400 to 300 seconds (5 minutes)
    compress               = true
  }

  # Cache behavior for static assets (CSS, JS, images)
  ordered_cache_behavior {
    path_pattern     = "/_astro/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0   # Reduced from 31536000 to 0
    default_ttl            = 300 # Reduced from 31536000 to 300 seconds (5 minutes)
    max_ttl                = 600 # Reduced from 31536000 to 600 seconds (10 minutes)
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Custom error response for SPA routing
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
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
    Name        = "astro-frontend-distribution"
    Environment = "production"
  }
}

# Update S3 bucket policy to allow CloudFront access
data "aws_iam_policy_document" "frontend_s3_policy_updated" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    effect = "Allow"
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

# Update bucket policy resource to use the new policy
resource "aws_s3_bucket_policy" "frontend_updated" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_s3_policy_updated.json

  depends_on = [aws_cloudfront_distribution.frontend]
}

# Output the CloudFront distribution domain name
output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_id" {
  description = "The identifier for the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend.id
}
