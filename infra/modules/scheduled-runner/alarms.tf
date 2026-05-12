resource "aws_cloudwatch_log_metric_filter" "runner_failed" {
  name           = "ducklake-runner-failed"
  log_group_name = aws_cloudwatch_log_group.runner.name
  pattern        = "PIPELINE_RUN_FAILED"

  metric_transformation {
    name      = "RunnerFailures"
    namespace = "DuckLake"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "runner_failed" {
  alarm_name          = "ducklake-runner-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RunnerFailures"
  namespace           = "DuckLake"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions

  tags = var.tags
}
