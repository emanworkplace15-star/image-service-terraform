output "function_arn" {
  description = "Processor function ARN."
  value       = var.create ? aws_lambda_function.processor[0].arn : null
}

output "function_name" {
  description = "Processor function name."
  value       = local.function_name
}

output "execution_role_arn" {
  description = "Execution role ARN (S3 read/write scoped to the image bucket)."
  value       = aws_iam_role.execution.arn
}