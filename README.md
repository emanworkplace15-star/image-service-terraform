# image-service — Terraform

Infrastructure for the image-service project: VPC `image`, RDS Postgres, an
EC2 app host running the backend + frontend containers, an ALB, the image
S3 bucket, and the image-processor Lambda wired to S3 events. GitHub Actions
deploys the three images to ECR over OIDC (no static keys anywhere).

## Layout

```
terraform/
├── bootstrap/            # one-time: S3 state bucket + DynamoDB lock table
├── modules/
│   ├── networking/       # VPC image, 2-AZ subnets, IGW, NAT + S3 endpoint, SGs
│   ├── ecr/              # 3 repositories (backend, frontend, lambda)
│   ├── iam-oidc/         # GitHub OIDC provider + shared CI role
│   ├── rds/              # Postgres + Secrets Manager (db-master, app secrets)
│   ├── s3/               # image bucket: private, CORS, lifecycle
│   ├── ec2-app/          # instance, instance-profile role, user_data
│   ├── alb/              # ALB + path-based routing
│   └── lambda/           # processor function + S3 notification
├── envs/dev/             # root module (remote state)
└── docs/DECISIONS.md     # every documented decision from the task list
```

## Usage

```bash
# 0. one-time (already done): create the state backend
cd terraform/bootstrap && terraform apply

# 1. bring up the stack (first run: create_lambda = false)
cd terraform/envs/dev
terraform init
terraform apply            # everything except the Lambda function

# 2. push the three repos to their forks' main branches → CI builds images
#    (see each repo's .github/workflows/deploy.yml; the frontend needs the
#    NEXT_PUBLIC_API_URL repository variable set to the ALB URL output)

# 3. after the lambda workflow's first green run:
terraform apply -var create_lambda=true   # function + S3 notification
```

## Key outputs

`terraform output` gives: `alb_url`, `rds_endpoint`, `db_master_secret_name`,
`app_secret_name`, `image_bucket`, `ecr_repositories`,
`github_actions_role_arn`, `app_instance_id`, `lambda_function_name`.

## Teardown

`terraform apply -var create_lambda=false` first (removes the S3 notification
and function), then `terraform destroy`. The state bucket is in `bootstrap/`.