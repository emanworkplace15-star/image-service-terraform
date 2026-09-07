output "instance_id" {
  description = "App instance ID."
  value       = aws_instance.app.id
}

output "instance_private_ip" {
  description = "Private IP of the app instance."
  value       = aws_instance.app.private_ip
}

output "instance_profile_role_arn" {
  description = "Role the app code assumes via the SDK default chain."
  value       = aws_iam_role.instance.arn
}

output "iam_role_name" {
  description = "Name of the instance profile role."
  value       = aws_iam_role.instance.name
}