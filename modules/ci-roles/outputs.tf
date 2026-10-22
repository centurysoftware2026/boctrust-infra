output "backend_deploy_role_arn" {
  description = "Set as the AWS role in the backend repo's deploy workflow."
  value       = aws_iam_role.backend_deploy.arn
}

output "admin_deploy_role_arn" {
  description = "Set as the AWS role in the admin repo's deploy workflow."
  value       = aws_iam_role.admin_deploy.arn
}
