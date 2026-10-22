output "state_bucket" {
  description = "Bucket to reference in each environment's S3 backend block."
  value       = aws_s3_bucket.state.id
}

output "github_oidc_provider_arn" {
  description = "GitHub OIDC provider, trusted by the ci-roles module."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "terraform_plan_role_arn" {
  value = aws_iam_role.terraform_plan.arn
}

output "terraform_apply_role_arn" {
  value = aws_iam_role.terraform_apply.arn
}
