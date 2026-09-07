output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.image.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.image.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (app, RDS)."
  value       = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  description = "Security group of the ALB."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group for app instances."
  value       = aws_security_group.app.id
}

output "rds_security_group_id" {
  description = "Security group for the database."
  value       = aws_security_group.rds.id
}