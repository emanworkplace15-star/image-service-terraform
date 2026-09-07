variable "function_name" {
  description = "Lambda function name."
  type        = string
  default     = "image-processor-lambda"
}

variable "create" {
  description = "Set false on a clean account (no image pushed yet); flip to true after the first CI push."
  type        = bool
  default     = true
}

variable "ecr_registry" {
  description = "ECR registry host."
  type        = string
}

variable "ecr_repo" {
  description = "ECR repository holding the processor image."
  type        = string
}

variable "image_tag" {
  description = "Image tag to run."
  type        = string
  default     = "latest"
}

variable "bucket_name" {
  description = "Image bucket name (also TARGET_BUCKET)."
  type        = string
}

variable "bucket_arn" {
  description = "Image bucket ARN (scopes the execution role)."
  type        = string
}

variable "backend_base_url" {
  description = "Base URL of the backend API (http://<alb-dns>); the handler appends /internal/images/events."
  type        = string
}

variable "lambda_api_key" {
  description = "App-level shared API key (sent as x-api-key to the backend)."
  type        = string
  sensitive   = true
}

variable "memory_size" {
  description = "Lambda memory (sharp scales with it)."
  type        = number
  default     = 512
}

variable "timeout_seconds" {
  description = "Function timeout."
  type        = number
  default     = 60
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the function."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}