variable "name_prefix" {
  description = "Name prefix for the bucket, distribution and function."
  type        = string
  default     = "image-service"
}

variable "use_cloudfront" {
  description = <<-EOT
    Serve via CloudFront (HTTPS, private bucket). False = S3 website
    endpoint over HTTP (dev fallback until the account is CloudFront-verified).
  EOT
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}