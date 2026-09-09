variable "name_prefix" {
  description = "Name prefix for the bucket, distribution and function."
  type        = string
  default     = "image-service"
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}