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

# Attach basic execution policy to Lambda role
resource "aws_iam_role_policy_attachment" "search_api_lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.search_api_lambda_role.name
}

# Search API Lambda function
resource "aws_lambda_function" "search_api" {
  filename      = data.archive_file.search_api_zip.output_path
  function_name = "search-api"
  role          = aws_iam_role.search_api_lambda_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 256
  architectures = ["arm64"]

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

# API Gateway Stage
resource "aws_api_gateway_stage" "search_api_stage" {
  deployment_id = aws_api_gateway_deployment.search_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.search_api_gateway.id
  stage_name    = "prod"
}

# Outputs
output "search_api_url" {
  description = "Search API Gateway URL"
  value       = "https://${aws_api_gateway_rest_api.search_api_gateway.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.search_api_stage.stage_name}"
}

output "search_options_endpoint" {
  description = "Search Options Endpoint"
  value       = "https://${aws_api_gateway_rest_api.search_api_gateway.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.search_api_stage.stage_name}/search/options"
}

output "search_endpoint" {
  description = "Search Endpoint"
  value       = "https://${aws_api_gateway_rest_api.search_api_gateway.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.search_api_stage.stage_name}/search"
}

# Data source for current region
data "aws_region" "current" {}
