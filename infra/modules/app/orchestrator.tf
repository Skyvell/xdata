data "aws_secretsmanager_secret" "dagster_agent_token" {
  name = var.dagster_agent_token_secret_name
}

resource "aws_cloudwatch_log_group" "dagster_agent" {
  name              = "/ducklake/dagster/agent"
  retention_in_days = 30
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "dagster_runs" {
  name              = "/ducklake/dagster/runs"
  retention_in_days = 30
  tags              = local.tags
}

resource "aws_ecs_cluster" "dagster" {
  name = "ducklake-dagster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "dagster" {
  cluster_name       = aws_ecs_cluster.dagster.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

resource "aws_service_discovery_private_dns_namespace" "dagster" {
  name        = "ducklake-dagster.local"
  description = "Service discovery namespace for Dagster code-location servers"
  vpc         = data.aws_vpc.default.id
  tags        = local.tags
}

locals {
  dagster_yaml = templatefile("${path.module}/dagster.yaml.tftpl", {
    deployment                     = var.dagster_deployment
    cluster_name                   = aws_ecs_cluster.dagster.name
    subnet_ids                     = data.aws_subnets.default.ids
    security_group_id              = aws_security_group.dagster.id
    service_discovery_namespace_id = aws_service_discovery_private_dns_namespace.dagster.id
    execution_role_arn             = aws_iam_role.dagster_task_execution.arn
    task_role_arn                  = aws_iam_role.dagster_run.arn
    log_group                      = aws_cloudwatch_log_group.dagster_runs.name
    server_cpu                     = var.dagster_server_cpu
    server_memory                  = var.dagster_server_memory
    run_cpu                        = var.dagster_run_cpu
    run_memory                     = var.dagster_run_memory
  })
}

resource "aws_ecs_task_definition" "dagster_agent" {
  family                   = "ducklake-dagster-agent"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.dagster_agent_cpu
  memory                   = var.dagster_agent_memory

  execution_role_arn = aws_iam_role.dagster_task_execution.arn
  task_role_arn      = aws_iam_role.dagster_agent.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name       = "agent"
    image      = var.dagster_agent_image
    essential  = true
    entryPoint = ["/bin/sh", "-c"]
    command = [
      join("; ", [
        "set -e",
        "mkdir -p /opt/dagster/dagster_home",
        "echo '${base64encode(local.dagster_yaml)}' | base64 -d > /opt/dagster/dagster_home/dagster.yaml",
        "exec dagster-cloud agent run /opt/dagster/dagster_home",
      ])
    ]
    environment = [
      { name = "DAGSTER_HOME", value = "/opt/dagster/dagster_home" },
    ]
    secrets = [
      {
        name      = "DAGSTER_CLOUD_AGENT_TOKEN"
        valueFrom = data.aws_secretsmanager_secret.dagster_agent_token.arn
      },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.dagster_agent.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "agent"
      }
    }
  }])

  tags = local.tags
}

resource "aws_ecs_service" "dagster_agent" {
  name            = "ducklake-dagster-agent"
  cluster         = aws_ecs_cluster.dagster.id
  task_definition = aws_ecs_task_definition.dagster_agent.arn
  desired_count   = var.dagster_agent_replicas
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.dagster.id]
    assign_public_ip = true
  }

  tags = local.tags
}
