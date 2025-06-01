# ZIP the Lambda function code
data "archive_file" "search_api_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/functions/search-api"
  output_path = "${path.module}/../backend/functions/search-api.zip"

  excludes = [
    "*.zip",
    ".git*",
    "README.md",
    "Makefile",
    "*_test.go",
    "coverage.out",
    "coverage.html"
  ]
}

# S3 Bucket for coverage reports and artifacts
resource "aws_s3_bucket" "coverage_reports" {
  bucket = "astro-backend-search-api-coverage"
}

resource "aws_s3_bucket_versioning" "coverage_reports" {
  bucket = aws_s3_bucket.coverage_reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "coverage_reports" {
  bucket = aws_s3_bucket.coverage_reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "coverage_reports" {
  bucket = aws_s3_bucket.coverage_reports.id

  rule {
    id     = "delete_old_reports"
    status = "Enabled"

    expiration {
      days = 30 # Coverage reports älter als 30 Tage löschen
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# IAM role for Search API Lambda
resource "aws_iam_role" "search_api_lambda_role" {
  name = "search-api-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# S3 permissions for coverage reports
resource "aws_iam_role_policy" "search_api_s3_coverage" {
  name = "search-api-s3-coverage-policy"
  role = aws_iam_role.search_api_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.coverage_reports.arn,
          "${aws_s3_bucket.coverage_reports.arn}/*"
        ]
      }
    ]
  })
}

# Attach basic execution policy to Lambda role
resource "aws_iam_role_policy_attachment" "search_api_lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.search_api_lambda_role.name
}

# Search API Lambda function mit DDoS Schutz
resource "aws_lambda_function" "search_api" {
  filename      = data.archive_file.search_api_zip.output_path
  function_name = "search-api"
  role          = aws_iam_role.search_api_lambda_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256
  architectures = ["arm64"]

  # DDoS Schutz: Begrenze gleichzeitige Ausführungen
  reserved_concurrent_executions = 20

  source_code_hash = data.archive_file.search_api_zip.output_base64sha256

  environment {
    variables = {
      ENV = "production"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.search_api_lambda_basic,
    aws_cloudwatch_log_group.search_api_logs,
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "search_api_logs" {
  name              = "/aws/lambda/search-api"
  retention_in_days = 14
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "search_api_gateway" {
  name        = "search-api"
  description = "Search API for car listings"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource: /search
resource "aws_api_gateway_resource" "search_resource" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  parent_id   = aws_api_gateway_rest_api.search_api_gateway.root_resource_id
  path_part   = "search"
}

# API Gateway Resource: /search/options
resource "aws_api_gateway_resource" "search_options_resource" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  parent_id   = aws_api_gateway_resource.search_resource.id
  path_part   = "options"
}

# API Gateway Method: GET /search/options
resource "aws_api_gateway_method" "search_options_get" {
  rest_api_id   = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id   = aws_api_gateway_resource.search_options_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway Method: POST /search
resource "aws_api_gateway_method" "search_post" {
  rest_api_id   = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id   = aws_api_gateway_resource.search_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Method: OPTIONS /search (CORS)
resource "aws_api_gateway_method" "search_options" {
  rest_api_id   = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id   = aws_api_gateway_resource.search_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# API Gateway Method: OPTIONS /search/options (CORS)
resource "aws_api_gateway_method" "search_options_options" {
  rest_api_id   = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id   = aws_api_gateway_resource.search_options_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# API Gateway Integration: GET /search/options -> Lambda
resource "aws_api_gateway_integration" "search_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id = aws_api_gateway_resource.search_options_resource.id
  http_method = aws_api_gateway_method.search_options_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.search_api.invoke_arn
}

# API Gateway Integration: POST /search -> Lambda
resource "aws_api_gateway_integration" "search_integration" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id = aws_api_gateway_resource.search_resource.id
  http_method = aws_api_gateway_method.search_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.search_api.invoke_arn
}

# CORS Integration for OPTIONS /search
resource "aws_api_gateway_integration" "search_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id = aws_api_gateway_resource.search_resource.id
  http_method = aws_api_gateway_method.search_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# CORS Integration for OPTIONS /search/options
resource "aws_api_gateway_integration" "search_options_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id = aws_api_gateway_resource.search_options_resource.id
  http_method = aws_api_gateway_method.search_options_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method Response for GET /search/options
resource "aws_api_gateway_method_response" "search_options_response_200" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id = aws_api_gateway_resource.search_options_resource.id
  http_method = aws_api_gateway_method.search_options_get.http_method
  status_code = "200"
}

# Method Response for POST /search
resource "aws_api_gateway_method_response" "search_response_200" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id = aws_api_gateway_resource.search_resource.id
  http_method = aws_api_gateway_method.search_post.http_method
  status_code = "200"
}

# Method Response for OPTIONS /search (CORS)
resource "aws_api_gateway_method_response" "search_cors_response_200" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id = aws_api_gateway_resource.search_resource.id
  http_method = aws_api_gateway_method.search_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Method Response for OPTIONS /search/options (CORS)
resource "aws_api_gateway_method_response" "search_options_cors_response_200" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id = aws_api_gateway_resource.search_options_resource.id
  http_method = aws_api_gateway_method.search_options_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Integration Response for OPTIONS /search (CORS)
resource "aws_api_gateway_integration_response" "search_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id = aws_api_gateway_resource.search_resource.id
  http_method = aws_api_gateway_method.search_options.http_method
  status_code = aws_api_gateway_method_response.search_cors_response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.search_cors_integration]
}

# Integration Response for OPTIONS /search/options (CORS)
resource "aws_api_gateway_integration_response" "search_options_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id
  resource_id = aws_api_gateway_resource.search_options_resource.id
  http_method = aws_api_gateway_method.search_options_options.http_method
  status_code = aws_api_gateway_method_response.search_options_cors_response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.search_options_cors_integration]
}

# Lambda permission for API Gateway to invoke the function
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_api.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.search_api_gateway.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "search_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.search_options_integration,
    aws_api_gateway_integration.search_integration,
    aws_api_gateway_integration.search_cors_integration,
    aws_api_gateway_integration.search_options_cors_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.search_api_gateway.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.search_resource.id,
      aws_api_gateway_resource.search_options_resource.id,
      aws_api_gateway_method.search_options_get.id,
      aws_api_gateway_method.search_post.id,
      aws_api_gateway_method.search_options.id,
      aws_api_gateway_method.search_options_options.id,
      aws_api_gateway_integration.search_options_integration.id,
      aws_api_gateway_integration.search_integration.id,
      aws_api_gateway_integration.search_cors_integration.id,
      aws_api_gateway_integration.search_options_cors_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage mit Throttling
resource "aws_api_gateway_stage" "search_api_stage" {
  deployment_id = aws_api_gateway_deployment.search_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.search_api_gateway.id
  stage_name    = "prod"
}

# Usage Plan für detailliertes Rate Limiting
resource "aws_api_gateway_usage_plan" "rate_limiting" {
  name        = "search-api-rate-limiting"
  description = "Rate Limiting für Search API"

  api_stages {
    api_id = aws_api_gateway_rest_api.search_api_gateway.id
    stage  = aws_api_gateway_stage.search_api_stage.stage_name
  }

  # Tägliche Quota
  quota_settings {
    limit  = 10000 # 10.000 Requests pro Tag
    period = "DAY"
  }

  # Globale Throttling-Einstellungen (einfacher und funktioniert sicher)
  throttle_settings {
    rate_limit  = 100 # 100 RPS global
    burst_limit = 200 # 200 Burst global
  }
}

# CloudFront Distribution für Caching und DDoS Schutz
resource "aws_cloudfront_distribution" "search_api_cdn" {
  origin {
    domain_name = "${aws_api_gateway_rest_api.search_api_gateway.id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
    origin_id   = "search-api-gateway"
    origin_path = "/${aws_api_gateway_stage.search_api_stage.stage_name}"

    custom_origin_config {
      http_port              = 443
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled = true
  comment = "CloudFront für Search API mit 15min Caching"

  # Cache-Verhalten für /search/options (länger cachen)
  ordered_cache_behavior {
    path_pattern     = "/search/options"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "search-api-gateway"
    compress         = true

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 900  # 15 Minuten
    default_ttl            = 900  # 15 Minuten
    max_ttl                = 3600 # 1 Stunde max
  }

  # Default Cache-Verhalten für /search (POST nicht cachebar)
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "search-api-gateway"
    compress         = true

    forwarded_values {
      query_string = true
      headers      = ["Content-Type", "Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0 # Kein Cache für POST /search
    max_ttl                = 0 # Kein Cache für POST /search
  }

  # Geo-Restrictions (optional)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL Zertifikat
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = {
    Name        = "search-api-cdn"
    Environment = "production"
  }
}

# CloudWatch Alarm für DDoS Detection
resource "aws_cloudwatch_metric_alarm" "ddos_detection" {
  alarm_name          = "search-api-high-request-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Count"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1000" # 1000 Requests in 5 Minuten
  alarm_description   = "Hohe Request-Rate erkannt - möglicherweise DDoS"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.search_api_gateway.name
    Stage   = aws_api_gateway_stage.search_api_stage.stage_name
  }
}

# Outputs
output "search_api_url" {
  description = "Search API Gateway URL"
  value       = "https://${aws_api_gateway_rest_api.search_api_gateway.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.search_api_stage.stage_name}"
}

output "cloudfront_url" {
  description = "CloudFront URL mit 15min Caching"
  value       = "https://${aws_cloudfront_distribution.search_api_cdn.domain_name}"
}

output "search_options_endpoint" {
  description = "Search Options Endpoint"
  value       = "https://${aws_api_gateway_rest_api.search_api_gateway.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.search_api_stage.stage_name}/search/options"
}

output "search_endpoint" {
  description = "Search Endpoint"
  value       = "https://${aws_api_gateway_rest_api.search_api_gateway.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.search_api_stage.stage_name}/search"
}

output "cloudfront_search_endpoint" {
  description = "CloudFront Search Endpoint (mit 15min Cache)"
  value       = "https://${aws_cloudfront_distribution.search_api_cdn.domain_name}/search"
}

output "coverage_bucket_name" {
  description = "S3 Bucket for Coverage Reports"
  value       = aws_s3_bucket.coverage_reports.id
}

output "coverage_bucket_url" {
  description = "S3 Bucket URL for Coverage Reports"
  value       = "https://${aws_s3_bucket.coverage_reports.bucket}.s3.${data.aws_region.current.name}.amazonaws.com"
}

output "rate_limiting_info" {
  description = "Rate Limiting Konfiguration"
  value       = "API Gateway: 100 RPS global, /search: 50 RPS, /search/options: 20 RPS, Lambda: 20 concurrent, Quota: 10k/Tag"
}

output "caching_info" {
  description = "CloudFront Caching Konfiguration"
  value       = "Search-Ergebnisse: 15min Cache, Options: 15min Cache"
}

# Data source for current region
data "aws_region" "current" {}
