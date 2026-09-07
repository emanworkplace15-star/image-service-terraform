# Three ECR repositories, one per service. Images are tagged with the commit
# SHA (immutable, what actually gets deployed) plus a rolling `latest`
# (convenience pointer for humans). See ../docs/DECISIONS.md for the scheme.

locals {
  repos = {
    backend  = "image-service-backend"
    frontend = "image-service-frontend"
    lambda   = "image-processor-lambda"
  }
}

resource "aws_ecr_repository" "this" {
  for_each = local.repos

  name                 = each.value
  image_tag_mutability = "MUTABLE" # `latest` moves; SHA tags are content-addressed anyway

  image_scanning_configuration {
    scan_on_push = true
  }

  # Keep dev costs bounded: 10 images per repo, expire the oldest.
  tags = merge(var.tags, {
    Name = each.value
  })
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.id

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Repository policy: allow this account's principals implicitly (default) —
# no cross-account access is configured.

output "repository_arns" {
  description = "Map of service -> repository ARN (used to scope the GitHub Actions role)."
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.arn
  }
}

output "repository_urls" {
  description = "Map of service -> repository URI."
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.repository_url
  }
}

output "repository_names" {
  description = "Map of service -> repository name (bare, without registry)."
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.name
  }
}