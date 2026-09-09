# Root module — wires the image-service stack together in region us-east-1.
#
#   networking -> rds / ec2-app / alb / lambda
#   ecr + iam-oidc are leaf resources (CI infra, Task 1)

data "aws_caller_identity" "current" {}

# Backend runtime secrets (DATABASE_URL / JWT_SECRET / LAMBDA_API_KEY) — the
# Lambda's API key is injected from here so it exists in exactly one place:
# Secrets Manager (and the encrypted state).
data "aws_secretsmanager_secret_version" "app" {
  secret_id = module.rds.app_secret_arn

  # The secret ID ordering doesn't cover the *version* write — wait for it
  # explicitly, otherwise the read races its creation.
  depends_on = [module.rds]
}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  name_prefix  = "image-service"
  frontend_url = "http://${module.alb.alb_dns_name}" # no domain/cert in dev yet
  # The static frontend is served by CloudFront (HTTPS by default) —
  # this is the origin browsers come from now, so CORS follows it.
  static_origin = module.static_site.domain

  # CI pushes :latest — the instance and the Lambda run it until a
  # deployment pins a SHA tag (workflows update the Lambda; the instance
  # re-pulls on rebootstrap).
  image_tag = "latest"
}

# ---------------- Task 1: CI foundation ----------------

module "ecr" {
  source = "../../modules/ecr"
}

module "github_oidc" {
  source = "../../modules/iam-oidc"

  github_organization = "emanworkplace15-star"
  allowed_repositories = [
    "image-service-backend",
    "image-service-frontend",
    "image-processor-lambda",
  ]
  lambda_function_name = "image-processor-lambda"
  aws_region           = var.aws_region
  ecr_repository_arns  = values(module.ecr.repository_arns)
  static_bucket_arn    = module.static_site.bucket_arn
  # Website mode: no distribution exists yet, but the IAM policy needs a
  # syntactically valid ARN — harmless placeholder until CloudFront is
  # account-verified and use_cloudfront flips to true.
  cloudfront_distribution_arn = (module.static_site.cloudfront_arn != ""
    ? module.static_site.cloudfront_arn
  : "arn:aws:cloudfront::${local.account_id}:distribution/none")
}

# ---------------- Static frontend (replaces the ECS frontend service) ----
# Next.js static export built by CI, synced to S3. CloudFront is blocked at
# the account level ("must be verified" 403 — tested twice, 2026-09-09), so
# dev serves via the S3 website endpoint (HTTP). Once AWS Support verifies
# the account for CloudFront, flip use_cloudfront to true.

module "static_site" {
  source = "../../modules/static-site"

  name_prefix    = local.name_prefix
  use_cloudfront = false
}

# ---------------- Task 2.1: network ----------------

module "networking" {
  source = "../../modules/networking"

  vpc_name      = "image"
  vpc_cidr      = var.vpc_cidr
  az_count      = 2
  backend_port  = 3001
  frontend_port = 3000
  rds_port      = 5432
}

# ---------------- Task 2.2: database + secrets ----------------

module "rds" {
  source = "../../modules/rds"

  private_subnet_ids = module.networking.private_subnet_ids
  security_group_id  = module.networking.rds_security_group_id

  instance_class        = "db.t3.micro"
  backup_retention_days = 1
}

# ---------------- Task 2.4: image bucket ----------------

module "s3" {
  source = "../../modules/s3"

  bucket_name         = "image-service-images-${local.account_id}"
  allowed_origins     = [local.static_origin] # browser uploads come from CloudFront now
  expire_uploads_days = null                  # originals kept (compressed copies live in processed/)
}

# ---------------- Task 2.5: ALB ----------------

module "alb" {
  source = "../../modules/alb"

  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
  # ip targets: the ECS services register their Fargate tasks themselves.
  target_type = "ip"
}

# ---------------- Task 2.3 Option B: ECS Fargate compute ----------------
# Same app, same ALB routing, same queue mode, same no-static-keys rule —
# only the compute platform changed (EC2 instance → Fargate tasks).

module "ecs" {
  source = "../../modules/ecs"

  name_prefix              = "image-service"
  private_subnet_ids       = module.networking.private_subnet_ids
  security_group_id        = module.networking.app_security_group_id
  backend_target_group_arn = module.alb.backend_target_group_arn
  app_secret_arn           = module.rds.app_secret_arn
  bucket_arn               = module.s3.bucket_arn
  sqs_queue_arn            = module.sqs.queue_arn
  sqs_queue_url            = module.sqs.queue_url
  ecr_registry             = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  image_tag                = local.image_tag
  s3_bucket                = module.s3.bucket_name
  aws_region               = var.aws_region
  cors_origin              = local.static_origin
}

# ---------------- Task 2.6: processor Lambda ----------------
# First apply on a clean account: create = false (no image pushed yet).
# After the lambda workflow's first green run, set create_lambda = true and
# re-apply to create the function + S3 event notification.

module "lambda" {
  source = "../../modules/lambda"

  create           = var.create_lambda
  ecr_registry     = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  ecr_repo         = module.ecr.repository_names.lambda
  image_tag        = local.image_tag
  bucket_name      = module.s3.bucket_name
  bucket_arn       = module.s3.bucket_arn
  backend_base_url = local.frontend_url
  lambda_api_key   = jsondecode(data.aws_secretsmanager_secret_version.app.secret_string)["LAMBDA_API_KEY"]
  sqs_queue_url    = module.sqs.queue_url
  sqs_queue_arn    = module.sqs.queue_arn
}

# ---------------- Queue mode: processor-events queue ----------------
# The Lambda publishes events here instead of calling the backend API
# directly; the backend's SqsEventConsumerService polls and deletes.
# Deploy order note: one apply updates both at once — the backend consumer
# simply starts polling an (initially) empty queue, so no ordering issue.
# Rollback: NOTIFY_MODE flips back to api in the lambda + ec2 modules.

module "sqs" {
  source = "../../modules/sqs"

  name_prefix                = local.name_prefix
  visibility_timeout_seconds = 120 # >= 2x worst-case Lambda processing
  max_receive_count          = 5
}