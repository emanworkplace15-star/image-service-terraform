output "alb_dns_name" {
  description = "Public URL host of the ALB (frontend origin + api base)."
  value       = aws_lb.main.dns_name
}

# frontend_target_group_arn output REMOVED — frontend is static now.

output "backend_target_group_arn" {
  description = "Backend target group ARN."
  value       = aws_lb_target_group.backend.arn
}