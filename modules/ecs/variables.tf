variable "name_prefix" {
  description = "Name prefix for cluster, services, roles, log groups."
  type        = string
  default     = "image-service"
}

variable "private_subnet_ids" {
  description = "Private subnets the Fargate tasks run in."
  type        = list(string)
}

variable "security_group_id" {
  description = "App security group (ingress from ALB, egress via NAT)."
  type        = string
}

variable "backend_target_group_arn" {
  description = "ALB target group for the backend (ip targets)."
  type        = string
}

variable "frontend_target_group_arn" {
  description = "ALB target group for the frontend (ip targets)."
  type        = string
}

variable "app_secret_arn" {
  description = "App secret ARN (DATABASE_URL / JWT_SECRET / LAMBDA_API_KEY injection)."
  type        = string
}

variable "bucket_arn" {
  description = "Image bucket ARN (backend task role S3 access)."
  type        = string
}

variable "sqs_queue_arn" {
  description = "Processor-events queue ARN (backend SQS consumer)."
  type        = string
}

variable "sqs_queue_url" {
  description = "Processor-events queue URL (backend env)."
  type        = string
}

variable "ecr_registry" {
  description = "ECR registry host (account.dkr.ecr.region.amazonaws.com)."
  type        = string
}

variable "image_tag" {
  description = "Image tag CI pushes (latest)."
  type        = string
  default     = "latest"
}

variable "s3_bucket" {
  description = "Image bucket name (backend env)."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "cors_origin" {
  description = "CORS origin for the backend (ALB URL)."
  type        = string
}

variable "backend_port" {
  description = "Backend container port."
  type        = number
  default     = 3001
}

variable "frontend_port" {
  description = "Frontend container port."
  type        = number
  default     = 3000
}

variable "desired_count" {
  description = "Tasks per service (single-tenant dev = 1)."
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory (MB)."
  type        = string
  default     = "512"
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}