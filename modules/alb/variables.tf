variable "name_prefix" {
  description = "Name prefix for ALB and target groups (max ~28 chars)."
  type        = string
  default     = "image-service"
}

variable "vpc_id" {
  description = "VPC to create target groups in."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group attached to the ALB."
  type        = string
}

variable "target_type" {
  description = "Target group target type: 'ip' for ECS Fargate tasks."
  type        = string
  default     = "ip"
}

variable "frontend_port" {
  description = "Frontend container port."
  type        = number
  default     = 3000
}

variable "backend_port" {
  description = "Backend container port."
  type        = number
  default     = 3001
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}