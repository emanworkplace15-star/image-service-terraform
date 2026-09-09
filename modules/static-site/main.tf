# Static frontend hosting: S3 bucket (+ CloudFront when verified).
#
#   CI builds the Next.js static export (out/) and s3-syncs it here.
#
#   use_cloudfront = true  -> private bucket, CloudFront (OAC) serves HTTPS,
#                             viewer-request function rewrites /login -> /login.html
#   use_cloudfront = false -> S3 website endpoint serves it over plain HTTP
#                             (dev fallback: this account needs AWS Support
#                             verification before new CloudFront resources
#                             are allowed).
#                             Website endpoints resolve directory paths to
#                             their index.html, so the export is built with
#                             trailingSlash: true (out/login/index.html).
#
#   NOTE: an apply with use_cloudfront = true fails with 403 "account must
#   be verified" until AWS Support lifts the CloudFront restriction —
#   after that, flip the flag in envs/dev and re-apply.

# ---------------- S3 bucket ----------------

resource "aws_s3_bucket" "static" {
  bucket = "${var.name_prefix}-static-frontend"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-static-frontend"
  })
}

resource "aws_s3_bucket_ownership_controls" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# CloudFront mode: block ALL public access — only CloudFront (OAC) reads.
# Website mode: object ACLs stay blocked; a public *bucket policy* is what
# lets anonymous GETs through, so block_public_policy must be off.
resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = var.use_cloudfront
  restrict_public_buckets = var.use_cloudfront
}

# ---------------- CloudFront mode ----------------

resource "aws_cloudfront_origin_access_control" "static" {
  count = var.use_cloudfront ? 1 : 0

  name                              = "${var.name_prefix}-static-oac"
  description                       = "CloudFront -> S3 static site origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "cloudfront_only" {
  count  = var.use_cloudfront ? 1 : 0
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
          "AWS:SourceArn" = aws_cloudfront_distribution.static[0].arn
        }
      }
    }]
  })
}

# Clean-URL rewrite (/login -> /login.html) — one .html file per route.
resource "aws_cloudfront_function" "url_rewrite" {
  count = var.use_cloudfront ? 1 : 0

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

resource "aws_cloudfront_distribution" "static" {
  count = var.use_cloudfront ? 1 : 0

  enabled         = true
  comment         = "image-service static frontend"
  price_class     = "PriceClass_100" # only N. America + Europe (cheapest)
  is_ipv6_enabled = true

  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "static-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.static[0].id
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
      function_arn = aws_cloudfront_function.url_rewrite[0].arn
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

# ---------------- Website mode (dev fallback) ----------------

resource "aws_s3_bucket_website_configuration" "static" {
  count  = var.use_cloudfront ? 0 : 1
  bucket = aws_s3_bucket.static.id

  index_document {
    suffix = "index.html"
  }

  # client-side routes have no real 404 page in this app; the shell is the
  # friendliest fallback we have
  error_document {
    key = "index.html"
  }
}

# Anonymous GET on objects — the website endpoint serves only what's here,
# and nothing in the bucket is secret (it's the public site itself).
resource "aws_s3_bucket_policy" "website_public_read" {
  count  = var.use_cloudfront ? 0 : 1
  bucket = aws_s3_bucket.static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadForWebsite"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject"]
      Resource  = "${aws_s3_bucket.static.arn}/*"
    }]
  })
}

# ---------------- Outputs ----------------

output "domain" {
  description = "Frontend origin URL (CloudFront HTTPS, or S3 website HTTP)."
  value = (var.use_cloudfront
    ? "https://${element(concat(aws_cloudfront_distribution.static[*].domain_name, [""]), 0)}"
    : "http://${element(concat(aws_s3_bucket_website_configuration.static[*].website_endpoint, [""]), 0)}"
  )
}

output "distribution_id" {
  description = "CloudFront distribution id (CI invalidations; empty in website mode)."
  value = element(
    concat(aws_cloudfront_distribution.static[*].id, [""]),
    0,
  )
}

output "cloudfront_arn" {
  description = "CloudFront distribution ARN (empty in website mode)."
  value = element(
    concat(aws_cloudfront_distribution.static[*].arn, [""]),
    0,
  )
}

output "bucket_name" {
  description = "Static assets bucket (CI syncs the export here)."
  value       = aws_s3_bucket.static.id
}

output "bucket_arn" {
  description = "Static bucket ARN (OIDC role push access)."
  value       = aws_s3_bucket.static.arn
}