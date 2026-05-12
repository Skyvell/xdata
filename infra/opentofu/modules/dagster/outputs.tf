output "dagster_cluster_name" {
  value = aws_ecs_cluster.dagster.name
}

output "dagster_agent_role_arn" {
  value = aws_iam_role.dagster_agent.arn
}

output "dagster_run_role_arn" {
  value = aws_iam_role.dagster_run.arn
}

output "compute_role_arn" {
  value       = aws_iam_role.dagster_run.arn
  description = "Alias of dagster_run_role_arn; the role assumed by user code launched by the Dagster agent."
}

output "dagster_url" {
  value = "https://${var.dagster_org_slug}.dagster.plus/${var.dagster_deployment}"
}

output "orchestration_image_repo" {
  value = aws_ecr_repository.orchestration.repository_url
}
