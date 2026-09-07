# Single t3.small in a private subnet running both containers under Docker.
# Containers come from ECR (pulled via the amazon-ecr-credential-helper with
# the instance role — no docker login keys), restart on reboot via
# --restart unless-stopped + the systemd docker service, and stream logs to
# CloudWatch through the awslogs driver.

locals {
  # user_data runs the start script under systemd so a failed/pending ECR
  # pull (images not pushed yet) retries instead of dying with the boot.
  backend_log_group  = "/${var.name_prefix}/backend"
  frontend_log_group = "/${var.name_prefix}/frontend"

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    app_secret_name    = var.app_secret_name
    ecr_registry       = var.ecr_registry
    backend_repo       = var.backend_repo
    frontend_repo      = var.frontend_repo
    backend_tag        = var.image_tag
    frontend_tag       = var.image_tag
    backend_log_group  = local.backend_log_group
    frontend_log_group = local.frontend_log_group
    aws_region         = var.aws_region
    s3_bucket          = var.s3_bucket
    cors_origin        = var.cors_origin
    backend_port       = var.backend_port
    frontend_port      = var.frontend_port
    sqs_queue_url      = var.sqs_queue_url
  })
}

# Container log destinations (created up front; the awslogs driver is set to
# not create groups itself).
resource "aws_cloudwatch_log_group" "backend" {
  name              = local.backend_log_group
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = local.frontend_log_group
  retention_in_days = var.log_retention_days

  tags = var.tags
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    # Standard AL2023 only — the wildcard matched ECS-optimized variants too.
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  key_name  = var.ssh_key_name
  user_data = local.user_data

  # Rebootstrap (fresh instance) whenever the user_data template changes.
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2          # SDK in a container still needs IMDS
  }

  root_block_device {
    volume_size = var.root_volume_gb # >= 30: the AL2023 AMI snapshot needs at least that
    volume_type = "gp3"
    encrypted   = true
  }

  # The containers restart on reboot via docker + --restart unless-stopped;
  # termination is deliberate only.
  instance_initiated_shutdown_behavior = "stop"

  tags = merge(var.tags, {
    Name = var.name_prefix
  })
}