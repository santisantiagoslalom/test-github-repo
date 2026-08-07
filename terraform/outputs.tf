output "bucket_name" {
  description = "Name of the example S3 bucket"
  value       = aws_s3_bucket.example.bucket
}

output "account_id" {
  description = "AWS account ID Terraform is operating in"
  value       = data.aws_caller_identity.current.account_id
}

output "test_security_group_id" {
  description = "ID of the locked-down test security group (no ingress/egress rules)"
  value       = aws_security_group.test_no_rules.id
}

output "sg_request_upload_bucket" {
  description = "Upload a *.csv file under incoming/ in this bucket to start a security group request"
  value       = aws_s3_bucket.sg_requests.bucket
}

output "sg_approval_api_endpoint" {
  description = "Base URL for the approve/reject links emailed to the approver"
  value       = aws_apigatewayv2_stage.sg_approval.invoke_url
}

output "sg_requests_table" {
  description = "DynamoDB table tracking security group request status"
  value       = aws_dynamodb_table.sg_requests.name
}

output "github_token_secret_arn" {
  description = "Secrets Manager secret to populate with a GitHub PAT (repo scope) after apply"
  value       = aws_secretsmanager_secret.github_token.arn
}
