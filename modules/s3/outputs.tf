output "bucket_name" {
  description = "Image bucket name (S3_BUCKET env var for backend + Lambda)."
  value       = aws_s3_bucket.images.id
}

output "bucket_arn" {
  description = "Image bucket ARN (scope IAM policies to it)."
  value       = aws_s3_bucket.images.arn
}

output "bucket_regional_domain_name" {
  description = "Regional endpoint of the bucket."
  value       = aws_s3_bucket.images.bucket_regional_domain_name
}