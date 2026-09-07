variable "bucket_name" {
  description = "Globally unique bucket name for image objects."
  type        = string
}

variable "allowed_origins" {
  description = <<-EOT
    Browser origins allowed to presign-PUT uploads and presign-GET gallery
    objects — the frontend's public URL(s), e.g. http://<alb-dns>.
  EOT
  type        = list(string)
  default     = ["*"] # tightened once the ALB DNS name is known — set in envs/dev
}

variable "expire_uploads_days" {
  description = "Days after which originals in uploads/ are deleted. null = never (compressed copies in processed/ are the gallery source)."
  type        = number
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}