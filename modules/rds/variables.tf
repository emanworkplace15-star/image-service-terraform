variable "db_identifier" {
  description = "RDS instance identifier."
  type        = string
  default     = "image-service-db"
}

variable "master_secret_name" {
  description = "Secrets Manager name holding the master credentials."
  type        = string
  default     = "image-service/dev/db-master"
}

variable "app_secret_name" {
  description = "Secrets Manager name holding backend runtime secrets."
  type        = string
  default     = "image-service/dev/app"
}

variable "database_name" {
  description = "Initial database name."
  type        = string
  default     = "imagedb"
}

variable "engine_version" {
  description = "Postgres engine version (latest 16.x available in us-east-1)."
  type        = string
  default     = "16.15"
}

variable "engine_version_major" {
  description = "Major version (parameter-group family)."
  type        = number
  default     = 16
}

variable "instance_class" {
  description = "RDS instance class — dev-sized."
  type        = string
  default     = "db.t3.micro"
}

variable "backup_retention_days" {
  description = "Backup retention (free-tier RDS allows at most 1 day)."
  type        = number
  default     = 1
}

variable "allocated_storage_gb" {
  description = "Initial storage (gp3)."
  type        = number
  default     = 20
}

variable "max_allocated_storage_gb" {
  description = "Storage autoscaling upper bound."
  type        = number
  default     = 100
}

variable "port" {
  description = "Database port."
  type        = number
  default     = 5432
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "security_group_id" {
  description = "RDS security group (ingress from the app SG only)."
  type        = string
}

variable "deletion_protection" {
  description = "Protect against accidental deletion (turn on for prod)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}