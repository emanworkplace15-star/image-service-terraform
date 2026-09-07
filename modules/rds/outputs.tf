output "endpoint" {
  description = "RDS connection endpoint (host:port)."
  value       = aws_db_instance.postgres.address
}

output "port" {
  description = "Database port."
  value       = aws_db_instance.postgres.port
}

output "database_name" {
  description = "Initial database name."
  value       = local.database_name
}

output "master_secret_arn" {
  description = "ARN of the master-credentials secret."
  value       = aws_secretsmanager_secret.db_master.arn
}

output "app_secret_arn" {
  description = "ARN of the app runtime-secrets secret (read by the EC2 profile role)."
  value       = aws_secretsmanager_secret.app.arn
}

output "app_secret_name" {
  description = "Name of the app runtime-secrets secret."
  value       = aws_secretsmanager_secret.app.name
}