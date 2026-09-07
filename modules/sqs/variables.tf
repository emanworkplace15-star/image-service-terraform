variable "name_prefix" {
  description = "Name prefix for the queues (e.g. image-service)."
  type        = string
  default     = "image-service"
}

variable "visibility_timeout_seconds" {
  description = "Queue visibility timeout — >= 2x worst-case processing time."
  type        = number
  default     = 120
}

variable "max_receive_count" {
  description = "Deliveries before a message redrives to the DLQ."
  type        = number
  default     = 5
}

variable "dlq_retention_seconds" {
  description = "DLQ message retention (max 1209600 = 14 days)."
  type        = number
  default     = 1209600
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}