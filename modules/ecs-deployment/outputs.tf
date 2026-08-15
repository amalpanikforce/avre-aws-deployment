output "cluster_name" {
  description = "ECS cluster name from the AWS infra repo."
  value       = var.cluster_name
}

output "service_name" {
  description = "ECS service name deployed by this repo."
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "Task definition ARN produced by this repo."
  value       = aws_ecs_task_definition.this.arn
}

output "task_definition_family" {
  description = "Task definition family name."
  value       = aws_ecs_task_definition.this.family
}

output "log_group_name" {
  description = "CloudWatch log group used by ECS"
  value       = var.log_group_name
}

output "execution_role_arn" {
  description = "Task execution role ARN used by the task definition."
  value       = var.execution_role_arn
}

output "task_role_arn" {
  description = "Task role ARN used by the task definition."
  value       = var.task_role_arn
}
