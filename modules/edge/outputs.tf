output "domain_name" {
  description = "Public host. Dashboard at the root, APIs at /api/<service>/api/v1."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.this.arn
}
