# ECS task identities — the no-static-keys invariant continues on ECS:
#   - execution role: what Fargate itself uses at LAUNCH (ECR pull, log
#     creation, reading the Secrets Manager entries the task def injects)
#   - backend task role: what the backend app sees at runtime (S3, SQS)
#   - frontend task role: exists but privilegeless — the frontend makes
#     no AWS API calls, yet a role keeps the SDK credential chain well-formed

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  execution_role_name = "${var.name_prefix}-ecs-execution-role"
  backend_role_name   = "${var.name_prefix}-ecs-backend-role"
  frontend_role_name  = "${var.name_prefix}-ecs-frontend-role"
}

# ---------------- Execution role (Fargate launch-time) ----------------

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = local.execution_role_name
  description        = "ECS Fargate launch-time: ECR pull, CloudWatch Logs, secret injection"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The managed execution policy covers ECR + logs but NOT Secrets Manager.
data "aws_iam_policy_document" "execution_secrets" {
  statement {
    sid    = "ReadAppSecretForInjection"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [var.app_secret_arn]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "secret-injection"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

# ---------------- Backend task role (runtime) ----------------

resource "aws_iam_role" "backend" {
  name               = local.backend_role_name
  description        = "Backend on ECS: S3 image access + SQS processor-event consumer"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

  tags = var.tags
}

data "aws_iam_policy_document" "backend_permissions" {
  # S3 — same access the instance role had.
  statement {
    sid    = "ImageBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [var.bucket_arn]
  }

  statement {
    sid    = "ImageBucketObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]
    resources = ["${var.bucket_arn}/*"]
  }

  # SQS consumer — NOTIFY_MODE=sqs: poll, handle, delete.
  statement {
    sid    = "ConsumeProcessorEvents"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [var.sqs_queue_arn]
  }
}

resource "aws_iam_role_policy" "backend" {
  name   = "${local.backend_role_name}-permissions"
  role   = aws_iam_role.backend.id
  policy = data.aws_iam_policy_document.backend_permissions.json
}

# Frontend task role REMOVED — static frontend makes no AWS calls and
# runs nowhere (S3 + CloudFront serve it).

output "task_role_arn" {
  description = "Backend task role ARN (S3 + SQS consumer)."
  value       = aws_iam_role.backend.arn
}

output "execution_role_arn" {
  description = "Task execution role ARN (ECR pull + secret injection)."
  value       = aws_iam_role.execution.arn
}