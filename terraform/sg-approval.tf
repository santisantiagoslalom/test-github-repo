# CSV-driven security group approval workflow:
# S3 upload -> csv_validator Lambda -> SES email -> API Gateway approve/reject
# -> approval_handler Lambda -> DynamoDB status update -> GitHub PR (applied by
# the existing terraform.yml pipeline once merged).

# --- Upload bucket ---

# ONE-TIME ADOPTION: local backend loses state between CI runs, so a partial
# apply already created this resource before this run's (empty) state knew
# about it. Safe to remove once applied successfully once.
import {
  to = aws_s3_bucket.sg_requests
  id = "sg-requests-250251693220"
}

resource "aws_s3_bucket" "sg_requests" {
  bucket = "sg-requests-${data.aws_caller_identity.current.account_id}"

  tags = {
    Environment = var.environment
    Purpose     = "sg-approval-csv-uploads"
  }
}

resource "aws_s3_bucket_public_access_block" "sg_requests" {
  bucket = aws_s3_bucket.sg_requests.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_notification" "sg_requests" {
  bucket = aws_s3_bucket.sg_requests.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.csv_validator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "incoming/"
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke_validator]
}

# --- Request tracking table ---
# (No import block here — the table was manually deleted, so Terraform
# should just create it fresh. Re-add an import block only if the real
# table already exists again and a fresh apply reports it as a duplicate.)

resource "aws_dynamodb_table" "sg_requests" {
  name         = "sg-approval-requests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }

  tags = {
    Environment = var.environment
  }
}

# --- GitHub PAT used by approval_handler to open pull requests ---
# Populate the value out-of-band (not via Terraform) so the token never lands in state or VCS:
#   aws secretsmanager put-secret-value --secret-id sg-approval/github-token --secret-string <PAT>

# ONE-TIME ADOPTION: see note on aws_s3_bucket.sg_requests above.
import {
  to = aws_secretsmanager_secret.github_token
  id = "sg-approval/github-token"
}

resource "aws_secretsmanager_secret" "github_token" {
  name        = "sg-approval/github-token"
  description = "GitHub PAT (repo scope) used to open PRs for approved security group requests"
}

# --- SES identities (sandbox mode requires both sender and recipient verified) ---

resource "aws_ses_email_identity" "sender" {
  email = var.sender_email
}

resource "aws_ses_email_identity" "approver" {
  email = var.approver_email
}

# --- Lambda packaging ---

data "archive_file" "csv_validator" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/csv_validator"
  output_path = "${path.module}/lambda/csv_validator.zip"
}

data "archive_file" "approval_handler" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/approval_handler"
  output_path = "${path.module}/lambda/approval_handler.zip"
}

# --- IAM: csv_validator ---

# ONE-TIME ADOPTION: see note on aws_s3_bucket.sg_requests above.
import {
  to = aws_iam_role.csv_validator
  id = "sg-approval-csv-validator"
}

resource "aws_iam_role" "csv_validator" {
  name = "sg-approval-csv-validator"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "csv_validator_logs" {
  role       = aws_iam_role.csv_validator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "csv_validator" {
  name = "sg-approval-csv-validator"
  role = aws_iam_role.csv_validator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.sg_requests.arn}/incoming/*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.sg_requests.arn
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "*"
      }
    ]
  })
}

# ONE-TIME ADOPTION: see note on aws_s3_bucket.sg_requests above.
import {
  to = aws_lambda_function.csv_validator
  id = "sg-approval-csv-validator"
}

resource "aws_lambda_function" "csv_validator" {
  function_name    = "sg-approval-csv-validator"
  role             = aws_iam_role.csv_validator.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.csv_validator.output_path
  source_code_hash = data.archive_file.csv_validator.output_base64sha256

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.sg_requests.name
      API_BASE_URL   = aws_apigatewayv2_stage.sg_approval.invoke_url
      APPROVER_EMAIL = var.approver_email
      SENDER_EMAIL   = var.sender_email
    }
  }
}

# ONE-TIME ADOPTION: see note on aws_s3_bucket.sg_requests above.
import {
  to = aws_lambda_permission.allow_s3_invoke_validator
  id = "sg-approval-csv-validator/AllowS3Invoke"
}

resource "aws_lambda_permission" "allow_s3_invoke_validator" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_validator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.sg_requests.arn
}

# --- IAM: approval_handler ---

# ONE-TIME ADOPTION: see note on aws_s3_bucket.sg_requests above.
import {
  to = aws_iam_role.approval_handler
  id = "sg-approval-handler"
}

resource "aws_iam_role" "approval_handler" {
  name = "sg-approval-handler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "approval_handler_logs" {
  role       = aws_iam_role.approval_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "approval_handler" {
  name = "sg-approval-handler"
  role = aws_iam_role.approval_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.sg_requests.arn
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.github_token.arn
      }
    ]
  })
}

# ONE-TIME ADOPTION: see note on aws_s3_bucket.sg_requests above.
import {
  to = aws_lambda_function.approval_handler
  id = "sg-approval-handler"
}

resource "aws_lambda_function" "approval_handler" {
  function_name    = "sg-approval-handler"
  role             = aws_iam_role.approval_handler.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.approval_handler.output_path
  source_code_hash = data.archive_file.approval_handler.output_base64sha256

  environment {
    variables = {
      TABLE_NAME              = aws_dynamodb_table.sg_requests.name
      GITHUB_OWNER            = var.github_owner
      GITHUB_REPO             = var.github_repo
      GITHUB_BASE_BRANCH      = var.github_base_branch
      GITHUB_TOKEN_SECRET_ARN = aws_secretsmanager_secret.github_token.arn
    }
  }
}

# --- API Gateway: approve/reject links ---

resource "aws_apigatewayv2_api" "sg_approval" {
  name          = "sg-approval-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "approval_handler" {
  api_id                 = aws_apigatewayv2_api.sg_approval.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.approval_handler.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "approve" {
  api_id    = aws_apigatewayv2_api.sg_approval.id
  route_key = "GET /approve/{request_id}"
  target    = "integrations/${aws_apigatewayv2_integration.approval_handler.id}"
}

resource "aws_apigatewayv2_route" "reject" {
  api_id    = aws_apigatewayv2_api.sg_approval.id
  route_key = "GET /reject/{request_id}"
  target    = "integrations/${aws_apigatewayv2_integration.approval_handler.id}"
}

# POST routes perform the actual mutation, triggered by the confirmation
# page's button — GET stays side-effect-free so email link scanners that
# auto-fetch URLs can't silently approve/reject on delivery.
resource "aws_apigatewayv2_route" "approve_confirm" {
  api_id    = aws_apigatewayv2_api.sg_approval.id
  route_key = "POST /approve/{request_id}"
  target    = "integrations/${aws_apigatewayv2_integration.approval_handler.id}"
}

resource "aws_apigatewayv2_route" "reject_confirm" {
  api_id    = aws_apigatewayv2_api.sg_approval.id
  route_key = "POST /reject/{request_id}"
  target    = "integrations/${aws_apigatewayv2_integration.approval_handler.id}"
}

resource "aws_apigatewayv2_stage" "sg_approval" {
  api_id      = aws_apigatewayv2_api.sg_approval.id
  name        = "$default"
  auto_deploy = true
}

# ONE-TIME ADOPTION: see note on aws_s3_bucket.sg_requests above.
import {
  to = aws_lambda_permission.allow_apigw_invoke_approval_handler
  id = "sg-approval-handler/AllowAPIGatewayInvoke"
}

resource "aws_lambda_permission" "allow_apigw_invoke_approval_handler" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.approval_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.sg_approval.execution_arn}/*/*"
}
