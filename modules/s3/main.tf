# Image bucket. Private end to end:
#   - Block Public Access on every knob
#   - no bucket policy granting anyone s3 access
#   - browsers reach objects only via presigned URLs the backend issues
#     (upload PUTs to uploads/*, gallery GETs from processed/*)
#   - Lambda reads uploads/* and writes processed/* through its execution role
#
# Key layout (documented convention, no infra for it — apps/S3-notification
# enforce it):
#   uploads/<imageId>.<ext>    originals, PUT by browser (presigned)
#   processed/<imageId>.jpg    Lambda's compressed output
#
# Lifecycle: originals are optional here — `uploads/` objects are transitioned
# to STANDARD_IA after 30 days and (only if var.expire_uploads_days is set)
# expired, since the compressed copy in processed/ remains the gallery
# source. Kept opt-in so the dev environment can't silently delete user data.

locals {
  bucket_name = var.bucket_name
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "images" {
  bucket = local.bucket_name

  tags = merge(var.tags, {
    Name = local.bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    object_ownership = "BucketOwnerEnforced" # no ACLs, policies only
  }
}

resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id

  versioning_configuration {
    status = "Enabled" # recover from accidental overwrite/delete
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "uploads-originals-tiering"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    dynamic "expiration" {
      for_each = var.expire_uploads_days == null ? [] : [var.expire_uploads_days]
      content {
        days = expiration.value
      }
    }
  }

  rule {
    id     = "expire-incomplete-multipart"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------- CORS (browser upload + gallery reads) ----------------
# Origins come from the ALB URL / any real domain the frontend is served on.
# Presigned PUT/GET requests hit this bucket from the browser directly, so
# the CORS config is what allows them — the bucket itself stays private.

resource "aws_s3_bucket_cors_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  cors_rule {
    id              = "browser-put-uploads"
    allowed_methods = ["PUT"]
    allowed_origins = var.allowed_origins
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  cors_rule {
    id              = "browser-get-gallery"
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.allowed_origins
    allowed_headers = ["*"]
    expose_headers  = ["ETag", "Content-Length", "Content-Type"]
    max_age_seconds = 3000
  }
}