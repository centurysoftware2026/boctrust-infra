output "bucket_name" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "object_access_policy_json" {
  description = "Least-privilege policy for task roles that read and write objects."
  value       = data.aws_iam_policy_document.object_access.json
}
