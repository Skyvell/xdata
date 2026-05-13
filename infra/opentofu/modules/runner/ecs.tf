resource "aws_cloudwatch_log_group" "runner" {
  name              = "/ducklake/runner"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_ecs_cluster" "runner" {
  name = "ducklake-runner"
  tags = var.tags
}

resource "aws_ecs_task_definition" "runner" {
  family                   = "ducklake-runner"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)

  execution_role_arn = aws_iam_role.runner_execution.arn
  task_role_arn      = aws_iam_role.runner_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "runner"
    image     = "${aws_ecr_repository.runner.repository_url}:${var.image_tag}"
    essential = true
    environment = [
      { name = "AWS_REGION", value = var.region },
      { name = "DUCKLAKE_HOST", value = var.catalog_host },
      { name = "DUCKLAKE_PORT", value = tostring(var.catalog_port) },
      { name = "DUCKLAKE_DB", value = var.catalog_db_name },
      { name = "DUCKLAKE_METADATA_SCHEMA", value = var.catalog_metadata_schema },
      { name = "DUCKLAKE_DATA_PATH", value = var.lake_data_path },
    ]
    secrets = [
      { name = "DUCKLAKE_USER", valueFrom = "${var.catalog_master_secret_arn}:username::" },
      { name = "DUCKLAKE_PASSWORD", valueFrom = "${var.catalog_master_secret_arn}:password::" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.runner.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "runner"
      }
    }
  }])

  tags = var.tags
}
