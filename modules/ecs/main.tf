# ECS (Fargate) compute — replaces the EC2 instance as the app platform.
#
#   ALB → backend service (3001) / frontend service (3000), ip targets in
#   private subnets. Each task runs from the CI-pushed ECR image with an
#   awslogs driver into the same log groups the stack has always used.
#
# What changed vs the EC2 module — and what deliberately did not:
#   - No instance, no user_data, no systemd: Fargate manages the runtime.
#   - Runtime secrets (DATABASE_URL / JWT_SECRET / LAMBDA_API_KEY) are
#     injected by ECS straight from Secrets Manager via the task definition
#     `secrets` block — the fetch-and-write-env-file dance is gone.
#   - No static keys anywhere, same as before: the execution role pulls the
#     image and reads secrets; the task role is what the app sees at
#     runtime (S3, SQS) via the default credential chain.
#   - The SQS consumer, S3 access, CORS, ports, log groups: identical.
#   - Missing images don't wedge anything: a Fargate service keeps retrying
#     task launches until CI pushes the image (no two-phase bootstrap).

# ---------------- Log groups (same names as the stack always used) --------

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/${var.name_prefix}/backend"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Frontend log group REMOVED — static frontend has no container logs.

# ---------------- Cluster ----------------

resource "aws_ecs_cluster" "main" {
  name = var.name_prefix

  setting {
    name  = "containerInsights"
    value = "disabled" # free-tier friendly
  }

  tags = var.tags
}

# ---------------- Task definitions ----------------

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.name_prefix}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory

  # Runtime identity (what the app sees) vs launch identity (what Fargate
  # itself sees) — two roles, both keyless.
  task_role_arn      = aws_iam_role.backend.arn
  execution_role_arn = aws_iam_role.execution.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${var.ecr_registry}/image-service-backend:${var.image_tag}"
      essential = true

      portMappings = [
        { containerPort = var.backend_port, protocol = "tcp" }
      ]

      # Runtime secrets injected at launch from Secrets Manager —
      # <secret-arn>:<jsonKey>:: syntax, one env var per key.
      secrets = [
        { name = "DATABASE_URL", valueFrom = "${var.app_secret_arn}:DATABASE_URL::" },
        { name = "JWT_SECRET", valueFrom = "${var.app_secret_arn}:JWT_SECRET::" },
        { name = "LAMBDA_API_KEY", valueFrom = "${var.app_secret_arn}:LAMBDA_API_KEY::" },
      ]

      environment = [
        { name = "NOTIFY_MODE", value = "sqs" },
        { name = "SQS_QUEUE_URL", value = var.sqs_queue_url },
        { name = "S3_BUCKET", value = var.s3_bucket },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "CORS_ORIGIN", value = var.cors_origin },
        { name = "PORT", value = tostring(var.backend_port) },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "backend"
          # no awslogs-create-group: Fargate rejects it when false, and
          # Terraform creates the group anyway
        }
      }
    }
  ])

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-backend"
  })
}

# Frontend task definition REMOVED — the frontend is static now
# (Next.js export on S3 + CloudFront, see modules/static-site).

# ---------------- Services ----------------

resource "aws_ecs_service" "backend" {
  name            = "backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = false # private subnets; egress via the NAT gateway
  }

  load_balancer {
    target_group_arn = var.backend_target_group_arn
    container_name   = "backend"
    container_port   = var.backend_port
  }

  # Let the task boot and pass the ALB health check before flipping the
  # deployment to healthy — avoids rollout flaps on cold starts.
  health_check_grace_period_seconds = 30

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-backend"
  })
}

# Frontend service REMOVED — static frontend lives on S3 + CloudFront.

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "backend_service_id" {
  description = "Backend service id (rollouts / debugging)."
  value       = aws_ecs_service.backend.id
}

# frontend_service_id output REMOVED — no frontend service anymore.