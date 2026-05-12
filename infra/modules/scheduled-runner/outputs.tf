output "runner_repository_url" {
  value       = aws_ecr_repository.runner.repository_url
  description = "ECR repository URL for the scheduled runner image."
}

output "runner_cluster_name" {
  value       = aws_ecs_cluster.runner.name
  description = "ECS cluster name used by scheduled runner tasks."
}

output "runner_cluster_arn" {
  value       = aws_ecs_cluster.runner.arn
  description = "ECS cluster ARN used by scheduled runner tasks."
}

output "runner_task_definition_arn" {
  value       = aws_ecs_task_definition.runner.arn
  description = "Scheduled runner ECS task definition ARN."
}

output "runner_task_role_arn" {
  value       = aws_iam_role.runner_task.arn
  description = "IAM role assumed by scheduled runner tasks."
}

output "runner_security_group_id" {
  value       = aws_security_group.runner.id
  description = "Security group id used by scheduled runner tasks."
}
