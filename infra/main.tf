terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket         = "astro-preset-terraform-state"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = "eu-central-1"
}


# Hole die aktuelle AWS Account ID dynamisch
data "aws_caller_identity" "current" {}

# OIDC Provider (falls noch nicht vorhanden)
data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::283919506801:oidc-provider/token.actions.githubusercontent.com"
}

resource "aws_iam_role" "astro_backend_cicd" {
  name = "astro-backend-cicd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com",
            "token.actions.githubusercontent.com:sub" : "repo:dyprodg/astro-backend-cicd:*",
          }
        }
      }
    ]
  })
}

# Beispiel-Policy: S3 Vollzugriff auf den Frontend-Bucket (passe ggf. an)
resource "aws_iam_role_policy" "astro_backend_cicd_policy" {
  name = "astro-backend-cicd-policy"
  role = aws_iam_role.astro_backend_cicd.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::astro-frontend-bucket",
          "arn:aws:s3:::astro-frontend-bucket/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:ListFunctions"
        ]
        Resource = [
          "arn:aws:lambda:eu-central-1:*:function:search-api"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::astro-backend-search-api-coverage",
          "arn:aws:s3:::astro-backend-search-api-coverage/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::astro-backend-data-bucket",
          "arn:aws:s3:::astro-backend-data-bucket/*"
        ]
      }
    ]
  })
}
