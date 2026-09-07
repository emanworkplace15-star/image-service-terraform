variable "aws_region" {
  description = "AWS region for the whole stack."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block of the `image` VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "create_lambda" {
  description = "false on a clean account until the first CI image push; then set true and re-apply."
  type        = bool
  default     = true
}