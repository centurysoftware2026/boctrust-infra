output "dns_name" {
  value = aws_lb.this.dns_name
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}

output "security_group_id" {
  value = aws_security_group.alb.id
}

output "origin_verify_secret" {
  value     = random_password.origin_verify.result
  sensitive = true
}
