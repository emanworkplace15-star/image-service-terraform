variable "oidc_thumbprints" {
  description = <<-EOT
    TLS root CA thumbprints GitHub's cert chains up to. IAM requires at least
    one entry; the two roots GitHub rotates between are pinned here.
  EOT
  type        = list(string)
  default = [
    "6938fd4d98bab03faadb97b343fb68cb0ec3691c",
    "9685f4542c19dd2129b8f9cf374cf9a1c6d0bc98",
  ]
}

variable "github_organization" {
  description = "GitHub account/org whose workflows may assume the role."
  type        = string
}

variable "allowed_repositories" {
  description = "Repo names (within the org) allowed to assume the role from main."
  type        = list(string)
}

variable "role_name" {
  description = "IAM role name for GitHub Actions."
  type        = string
  default     = "GitHubActionsWorkflowRole"
}

variable "lambda_function_name" {
  description = "Lambda function the role may update code on."
  type        = string
}

variable "aws_region" {
  description = "Region used to build the lambda function ARN."
  type        = string
}

variable "ecr_repository_arns" {
  description = "Exact ECR repository ARNs the role may push to."
  type        = list(string)
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}