output "alb_url" {
  description = "Public entry point — frontend origin and API base URL."
  value       = local.frontend_url
}

output "rds_endpoint" {
  description = "RDS Postgres endpoint (host:port)."
  value       = module.rds.endpoint
}

output "db_master_secret_name" {
  description = "Secrets Manager secret with RDS master credentials."
  value       = module.rds.master_secret_arn
}

output "app_secret_name" {
  description = "Secrets Manager secret with backend runtime secrets (DATABASE_URL, JWT_SECRET, LAMBDA_API_KEY)."
  value       = module.rds.app_secret_name
}

output "image_bucket" {
  description = "Image bucket (uploads/ originals, processed/ compressed)."
  value       = module.s3.bucket_name
}

output "ecr_repositories" {
  description = "ECR repository URIs the workflows push to."
  value       = module.ecr.repository_urls
}

output "github_actions_role_arn" {
  description = "Role the workflows assume via OIDC."
  value       = module.github_oidc.role_arn
}

output "app_instance_id" {
  description = "App EC2 instance (SSM Session Manager to reach it)."
  value       = module.ec2_app.instance_id
}

output "lambda_function_name" {
  description = "Processor Lambda (null until create_lambda = true)."
  value       = module.lambda.function_name
}
output "sqs_queue_url" {
  description = "Processor-events queue URL (backend consumer + Lambda publisher)."
  value       = module.sqs.queue_url
}

output "sqs_dlq_url" {
  description = "Processor-events DLQ URL (should stay empty)."
  value       = module.sqs.dlq_url
}
