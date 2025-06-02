# ============================================
# Contact Form / Mailer Infrastructure
# ============================================

# Variables
variable "sender_email" {
  description = "The verified SES sender email address"
  default     = "info@dennisdiepolder.com"
}

variable "recipient_email" {
  description = "The email address to receive form submissions"
  default     = "info@dennisdiepolder.com"
}

# ZIP the Lambda function code
data "archive_file" "contact_form_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend/functions/contact-form"
  output_path = "${path.module}/../backend/functions/contact-form.zip"

  excludes = [
    "*.zip",
    ".git*",
    "README.md",
    "Makefile",
    "*_test.go",
    "coverage.out",
    "coverage.html",
    "go.mod",
    "go.sum"
  ]
}

# IAM role for Contact Form Lambda
resource "aws_iam_role" "contact_form_lambda_role" {
  name = "contact-form-lambda-role"

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

# SES permissions for sending emails
resource "aws_iam_role_policy" "contact_form_ses_policy" {
  name = "contact-form-ses-policy"
  role = aws_iam_role.contact_form_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ses:FromAddress" = var.sender_email
          }
        }
      }
    ]
  })
}

# Attach basic execution policy to Lambda role
resource "aws_iam_role_policy_attachment" "contact_form_lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.contact_form_lambda_role.name
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "contact_form_logs" {
  name              = "/aws/lambda/contact-form"
  retention_in_days = 14
}

# Contact Form Lambda function
resource "aws_lambda_function" "contact_form" {
  filename      = data.archive_file.contact_form_zip.output_path
  function_name = "contact-form"
  role          = aws_iam_role.contact_form_lambda_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 128
  architectures = ["arm64"]

  # Rate limiting
  reserved_concurrent_executions = 10

  source_code_hash = data.archive_file.contact_form_zip.output_base64sha256

  environment {
    variables = {
      ENV             = "production"
      SENDER_EMAIL    = var.sender_email
      RECIPIENT_EMAIL = var.recipient_email
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.contact_form_lambda_basic,
    aws_cloudwatch_log_group.contact_form_logs,
  ]
}

# API Gateway REST API for Contact Form
resource "aws_api_gateway_rest_api" "contact_form_api" {
  name        = "contact-form-api"
  description = "API for contact form submissions"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource: /contact
resource "aws_api_gateway_resource" "contact_resource" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  parent_id   = aws_api_gateway_rest_api.contact_form_api.root_resource_id
  path_part   = "contact"
}

# API Gateway Method: POST /contact
resource "aws_api_gateway_method" "contact_post" {
  rest_api_id   = aws_api_gateway_rest_api.contact_form_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Method: OPTIONS /contact (CORS)
resource "aws_api_gateway_method" "contact_options" {
  rest_api_id   = aws_api_gateway_rest_api.contact_form_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# API Gateway Integration: POST /contact -> Lambda
resource "aws_api_gateway_integration" "contact_integration" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.contact_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.contact_form.invoke_arn
}

# CORS Integration for OPTIONS /contact
resource "aws_api_gateway_integration" "contact_cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.contact_options.http_method

  type = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method Response for POST /contact
resource "aws_api_gateway_method_response" "contact_response_200" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.contact_post.http_method
  status_code = "200"
}

# Method Response for OPTIONS /contact (CORS)
resource "aws_api_gateway_method_response" "contact_cors_response_200" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.contact_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Integration Response for OPTIONS /contact (CORS)
resource "aws_api_gateway_integration_response" "contact_cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.contact_options.http_method
  status_code = aws_api_gateway_method_response.contact_cors_response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.contact_cors_integration]
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "contact_api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_form.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.contact_form_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "contact_form_deployment" {
  depends_on = [
    aws_api_gateway_integration.contact_integration,
    aws_api_gateway_integration.contact_cors_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.contact_resource.id,
      aws_api_gateway_method.contact_post.id,
      aws_api_gateway_method.contact_options.id,
      aws_api_gateway_integration.contact_integration.id,
      aws_api_gateway_integration.contact_cors_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage mit Rate Limiting
resource "aws_api_gateway_stage" "contact_form_stage" {
  deployment_id = aws_api_gateway_deployment.contact_form_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.contact_form_api.id
  stage_name    = "prod"
}

# Usage Plan für Rate Limiting
resource "aws_api_gateway_usage_plan" "contact_form_rate_limiting" {
  name        = "contact-form-rate-limiting"
  description = "Rate Limiting für Contact Form API"

  api_stages {
    api_id = aws_api_gateway_rest_api.contact_form_api.id
    stage  = aws_api_gateway_stage.contact_form_stage.stage_name
  }

  # Quota: 1000 Anfragen pro Tag (um Spam zu vermeiden)
  quota_settings {
    limit  = 1000
    period = "DAY"
  }

  # Throttling: 10 Requests pro Sekunde
  throttle_settings {
    rate_limit  = 10
    burst_limit = 20
  }
}

# CloudWatch Alarm für hohe Fehlerrate
resource "aws_cloudwatch_metric_alarm" "contact_form_errors" {
  alarm_name          = "contact-form-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Triggers when contact form Lambda has high error rate"

  dimensions = {
    FunctionName = aws_lambda_function.contact_form.function_name
  }
}

# SES Email Identity (muss manuell verifiziert werden)
resource "aws_ses_email_identity" "sender" {
  email = var.sender_email
}

resource "aws_ses_email_identity" "recipient" {
  email = var.recipient_email
}

# Outputs
output "contact_form_api_url" {
  description = "Contact Form API Gateway URL"
  value       = "https://${aws_api_gateway_rest_api.contact_form_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.contact_form_stage.stage_name}"
}

output "contact_form_endpoint" {
  description = "Contact Form Endpoint"
  value       = "https://${aws_api_gateway_rest_api.contact_form_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.contact_form_stage.stage_name}/contact"
}

output "ses_sender_email" {
  description = "SES Sender Email (must be verified)"
  value       = var.sender_email
}

output "ses_recipient_email" {
  description = "SES Recipient Email (must be verified)"
  value       = var.recipient_email
}

output "ses_verification_note" {
  description = "Important SES verification note"
  value       = "WICHTIG: info@dennisdiepolder.com muss in AWS SES verifiziert werden, bevor E-Mails gesendet werden können!"
}
