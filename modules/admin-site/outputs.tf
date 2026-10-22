output "bucket_name" {
  value = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "origin" {
  description = "Pass to the edge module as admin_site."
  value = {
    bucket_regional_domain_name = aws_s3_bucket.this.bucket_regional_domain_name
    origin_access_control_id    = aws_cloudfront_origin_access_control.this.id
  }
}
