terraform {
  backend "s3" {
    bucket         = "image-service-tfstate-233338945000"
    key            = "image-service/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = false # classic DynamoDB locking via terraform-locks
    dynamodb_table = "terraform-locks"
  }
}