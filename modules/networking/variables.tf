variable "vpc_name" {
  description = "Name tag for the VPC and derived resources."
  type        = string
  default     = "image"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread public/private subnet pairs over."
  type        = number
  default     = 2
}

variable "backend_port" {
  description = "Container port the backend listens on."
  type        = number
  default     = 3001
}

variable "frontend_port" {
  description = "Container port the frontend listens on."
  type        = number
  default     = 3000
}

variable "rds_port" {
  description = "Database port."
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}