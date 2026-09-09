# Static frontend hosting: S3 bucket + CloudFront.
#
#   CI builds the Next.js static export (out/) and s3-syncs it here;
#   CloudFront serves it over HTTPS through an Origin Access Control —
#   the bucket has no public access at all (same no-keys rule as the
#   rest of the stack: access flows through a resource policy, not ACLs).
#
#   viewer-request function rewrites clean URLs: /login -> /login.html
#   (Next.js static export writes one .html file per route).

# ---------------- Origin Access Control ----------------

resource "aws_cloudfront_origin_access_control" "static" {
  name                              = "${var.name_prefix}-static-oac"
  description                       = "CloudFront -> S3 static site origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---------------- S3 bucket ----------------

resource "aws_s3_bucket" "static" {
  bucket = "${var.name_prefix}-static-frontend"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-static-frontend"
  })
}

# Block ALL public access — only CloudFront (OAC) can read.
resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = ["s3:GetObject"]
      Resource  = "${aws_s3_bucket.static.arn}/*"
      Condition = {
        StringEquals = {
          # only this distribution may read — not every CF in the account
          "AWS:SourceArn" = aws_cloudfront_distribution.static.arn
        }
      }
    }]
  })
}

# ---------------- Clean-URL rewrite (/login -> /login.html) ----------

resource "aws_cloudfront_function" "url_rewrite" {
  name    = "${var.name_prefix}-static-url-rewrite"
  comment = "Append index.html / .html for the Next.js static export"
  runtime = "cloudfront-js-2.0"
  publish = true

  code = <<-JS
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
      } else if (!uri.split('/').pop().includes('.')) {
        request.uri = uri + '.html';
      }
      return request;
    }
  JS
}

# ---------------- Distribution ----------------

resource "aws_cloudfront_distribution" "static" {
  enabled         = true
  comment         = "image-service static frontend"
  price_class     = "PriceClass_100" # only N. America + Europe (cheapest)
  is_ipv6_enabled = true

  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "static-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.static.id
  }

  default_cache_behavior {
    target_origin_id       = "static-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # static export assets are content-addressed; keep it simple
    default_ttl = 60
    max_ttl     = 300

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.url_rewrite.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}

# ---------------- Outputs ----------------

output "domain" {
  description = "CloudFront domain (the new frontend origin)."
  value       = "https://${aws_cloudfront_distribution.static.domain_name}"
}

output "distribution_id" {
  description = "CloudFront distribution id (CI invalidations)."
  value       = aws_cloudfront_distribution.static.id
}

output "bucket_name" {
  description = "Static assets bucket (CI syncs the export here)."
  value       = aws_s3_bucket.static.id
}

output "bucket_arn" {
  description = "Static bucket ARN (OIDC role push access)."
  value       = aws_s3_bucket.static.arn
}