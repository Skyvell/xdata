resource "aws_scheduler_schedule" "runner" {
  for_each = var.schedules

  name                = "ducklake-${each.key}"
  group_name          = "default"
  schedule_expression = each.value.schedule_expression
  state               = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_ecs_cluster.runner.arn
    role_arn = aws_iam_role.scheduler.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.runner.arn
      launch_type         = "FARGATE"

      network_configuration {
        subnets          = var.subnet_ids
        security_groups  = [aws_security_group.runner.id]
        assign_public_ip = var.assign_public_ip
      }
    }

    input = jsonencode({
      containerOverrides = [{
        name    = "runner"
        command = each.value.command
      }]
    })
  }
}
