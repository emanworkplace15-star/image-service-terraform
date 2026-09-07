# The instance's identity: an instance-profile role the SDK's default
# credential chain picks up automatically. No AWS access keys exist for the
# app — it talks to S3 and Secrets Manager through this role.

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  role_name = "${var.name_prefix}-instance-role"
}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = local.role_name
  description        = "App instance: S3 image access, Secrets Manager reads, SSM access"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = merge(var.tags, {
    Name = local.role_name
  })
}

data "aws_iam_policy_document" "instance_permissions" {
  # 1. Object storage — read/write on the image bucket only.
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

  # 2. Runtime secrets — read the app secret (DB URL, JWT, Lambda API key).
  statement {
    sid    = "ReadAppSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [var.app_secret_arn]
  }

  # 3. SSM — Session Manager shell access, no SSH keys needed.
  statement {
    sid    = "SsmSession"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "ssm:UpdateInstanceInformation",
    ]
    resources = ["*"]
  }

  # 4. ECR image pulls — the amazon-ecr-credential-helper authenticates every
  #    docker pull through this role; no registry login tokens on disk.
  statement {
    sid       = "EcrGetAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # not resource-scopable
  }

  statement {
    sid    = "EcrImagePull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
    ]
    resources = var.ecr_repository_arns
  }

  # 5. Container stdout -> CloudWatch Logs (awslogs docker driver).
  statement {
    sid    = "ContainerLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/${var.name_prefix}/backend:log-stream:*",
      "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/${var.name_prefix}/frontend:log-stream:*",
    ]
  }
}

resource "aws_iam_role_policy" "instance" {
  name   = "${local.role_name}-permissions"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.instance_permissions.json
}

# SSM agent needs the managed-instance core policy to register the node.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.instance.name

  tags = var.tags
}