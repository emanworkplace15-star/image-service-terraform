variable "name_prefix" {
  description = "Prefix for the instance and IAM names."
  type        = string
  default     = "image-service"
}

variable "instance_type" {
  description = "EC2 instance type for the app host."
  type        = string
  default     = "t3.small"
}

variable "private_subnet_id" {
  description = "Private subnet to place the instance in."
  type        = string
}

variable "security_group_id" {
  description = "App security group (ALB -> container ports)."
  type        = string
}

variable "ssh_key_name" {
  description = "Optional EC2 key pair for SSH (SSM Session Manager is the primary access path)."
  type        = string
  default     = null
}

variable "root_volume_gb" {
  description = "Root EBS volume size (AL2023 AMI requires >= 30)."
  type        = number
  default     = 30
}

variable "ecr_registry" {
  description = "ECR registry host, e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com."
  type        = string
}

variable "backend_repo" {
  description = "Backend ECR repository name."
  type        = string
}

variable "frontend_repo" {
  description = "Frontend ECR repository name."
  type        = string
}

variable "image_tag" {
  description = "Image tag the instance runs (latest until a CI push lands)."
  type        = string
  default     = "latest"
}

variable "app_secret_name" {
  description = "Secrets Manager secret the instance reads at boot."
  type        = string
}

variable "app_secret_arn" {
  description = "ARN of the app secret (scopes the instance role's read)."
  type        = string
}

variable "bucket_arn" {
  description = "Image bucket ARN (scopes the instance role's S3 access)."
  type        = string
}

variable "ecr_repository_arns" {
  description = "ARNs of the ECR repos the instance pulls images from."
  type        = list(string)
}

variable "sqs_queue_arn" {
  description = "Processor-events queue ARN the backend consumes (NOTIFY_MODE=sqs)."
  type        = string
}

variable "sqs_queue_url" {
  description = "Processor-events queue URL passed to the backend container env."
  type        = string
}

variable "aws_region" {
  description = "AWS region (S3_BUCKET/AWS_REGION env vars + awslogs driver)."
  type        = string
}

variable "s3_bucket" {
  description = "Image bucket name passed to the backend as S3_BUCKET."
  type        = string
}

variable "cors_origin" {
  description = "CORS_ORIGIN for the backend (the frontend's public URL)."
  type        = string
  default     = "*"
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

variable "log_retention_days" {
  description = "CloudWatch Logs retention for container log groups."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}