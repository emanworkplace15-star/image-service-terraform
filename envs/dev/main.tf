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
  allowed_origins     = [local.frontend_url]
  expire_uploads_days = null # originals kept (compressed copies live in processed/)
}

# ---------------- Task 2.5: ALB ----------------

module "alb" {
  source = "../../modules/alb"

  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
  instance_id           = module.ec2_app.instance_id
}

# ---------------- Task 2.3 Option A: EC2 compute ----------------

module "ec2_app" {
  source = "../../modules/ec2-app"

  private_subnet_id = module.networking.private_subnet_ids[0] # same AZ as the NAT gateway
  security_group_id = module.networking.app_security_group_id
  app_secret_name   = module.rds.app_secret_name
  app_secret_arn    = module.rds.app_secret_arn
  bucket_arn        = module.s3.bucket_arn
  ecr_repository_arns = [
    module.ecr.repository_arns.backend,
    module.ecr.repository_arns.frontend,
  ]
  ecr_registry      = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  # Bare repo names — the user_data template prefixes the registry itself.
  backend_repo      = module.ecr.repository_names.backend
  frontend_repo     = module.ecr.repository_names.frontend
  image_tag         = local.image_tag
  aws_region        = var.aws_region
  s3_bucket         = module.s3.bucket_name
  cors_origin       = local.frontend_url
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
}