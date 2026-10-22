output "security_group_id" {
  value = aws_security_group.this.id
}

output "task_definition_family" {
  value = aws_ecs_task_definition.this.family
}
