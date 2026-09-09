output "alb_url" {
  description = "Backend API base URL (the Lambda calls the backend here)."
  value       = local.frontend_url
}

output "static_site_url" {
  description = "Frontend entry point (CloudFront, HTTPS)."
  value       = module.static_site.domain
}

output "static_distribution_id" {
  description = "CloudFront distribution id (CI invalidations)."
  value       = module.static_site.distribution_id
}

output "static_bucket_name" {
  description = "Static frontend bucket (CI syncs the Next.js export here)."
  value       = module.static_site.bucket_name
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

output "ecs_cluster_name" {
  description = "ECS cluster (services live here — aws ecs describe-services to debug)."
  value       = module.ecs.cluster_name
}

output "ecs_service_ids" {
  description = "Backend service id (rollouts / debugging). Frontend is static now."
  value       = { backend = module.ecs.backend_service_id }
}

output "backend_task_role_arn" {
  description = "Backend runtime role (S3 + SQS consumer) — injected via task role."
  value       = module.ecs.task_role_arn
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
