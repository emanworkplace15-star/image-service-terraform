# GitHub OIDC federation, set up once at the account level:
#   1. One OIDC provider for token.actions.githubusercontent.com
#   2. ONE shared role for GitHub Actions (all three repos assume it)
#   3. Least-privilege permissions policy: ECR push on exactly the three
#      image-service repos + update of the processor Lambda.
#
# No static AWS access keys live in any repo secret. The trust policy scopes
# `sub` to repo:emanworkplace15-star/* on refs/heads/main, so:
#   - repos outside this GitHub account are denied at the trust layer
#   - repos inside the account but not in the permissions policy (e.g. the
#     dependency-check fork) can assume the role yet can act on nothing.
# Branch scoping additionally denies forks' other branches from assuming it.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  github_org  = var.github_organization
  role_name   = var.role_name
  oidc_url    = "token.actions.githubusercontent.com"
  lambda_name = var.lambda_function_name
}

# ---------------- OIDC provider (account-level, once) ----------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://${local.oidc_url}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.oidc_thumbprints
}

# ---------------- Trust policy ----------------

data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_url}:sub"
      # GitHub's sub claim can embed ids in two places:
      #   repo:org/repo:ref:refs/heads/main                      (plain)
      #   repo:org@<org-id>/repo@<run-id>:ref:refs/heads/main    (id-annotated)
      # Accept every combination, but never loosen below the repo/branch level.
      values = flatten([
        for repo in var.allowed_repositories : [
          "repo:${local.github_org}/${repo}:ref:refs/heads/main",
          "repo:${local.github_org}/${repo}@*:ref:refs/heads/main",
          "repo:${local.github_org}@*/${repo}:ref:refs/heads/main",
          "repo:${local.github_org}@*/${repo}@*:ref:refs/heads/main",
        ]
      ])
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = local.role_name
  description        = "Shared GitHub Actions deploy role (OIDC, no static keys)"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json

  # Web identity credentials expire quickly; sessions are capped at the max.
  max_session_duration = 3600

  tags = merge(var.tags, {
    Name = local.role_name
  })
}

# ---------------- Least-privilege permissions ----------------

data "aws_iam_policy_document" "github_actions_permissions" {
  # 1. Docker client auth against the registry.
  statement {
    sid    = "EcrGetAuthorizationToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"] # GetAuthorizationToken is not resource-scopable
  }

  # 2. Push + pull only on the three image-service repositories.
  statement {
    sid    = "EcrImagePushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = var.ecr_repository_arns
  }

  # 3. Update the processor Lambda's code from the pushed image, and read
  # its status so the workflow can wait for the update to apply.
  statement {
    sid    = "LambdaUpdateFunctionCode"
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:lambda:${var.aws_region}:${local.account_id}:function:${local.lambda_name}",
    ]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${local.role_name}-permissions"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

output "role_arn" {
  description = "ARN to put in role-to-assume in the workflows."
  value       = aws_iam_role.github_actions.arn
}

output "role_name" {
  description = "Shared GitHub Actions role name."
  value       = aws_iam_role.github_actions.name
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN (the trust anchor)."
  value       = aws_iam_openid_connect_provider.github.arn
}