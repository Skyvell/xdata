data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Task execution role: ECS uses this to pull images, read secrets, write logs.
resource "aws_iam_role" "dagster_task_execution" {
  name               = "ducklake-dagster-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "dagster_task_execution_managed" {
  role       = aws_iam_role.dagster_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "dagster_task_execution_extra" {
  statement {
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecrets",
      "secretsmanager:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "dagster_task_execution_extra" {
  name   = "secrets-and-tags"
  role   = aws_iam_role.dagster_task_execution.id
  policy = data.aws_iam_policy_document.dagster_task_execution_extra.json
}

# Agent role: task role for the long-running agent. Launches and supervises
# run/server tasks via ECS + Cloud Map. Action list mirrors Dagster's official
# CloudFormation template (s3://dagster.cloud/cloudformation/ecs-agent.yaml).
resource "aws_iam_role" "dagster_agent" {
  name               = "ducklake-dagster-agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "dagster_agent" {
  statement {
    sid = "EcsManageTasksAndServices"
    actions = [
      "ecs:CreateService",
      "ecs:DeleteService",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecs:DescribeTaskDefinition",
      "ecs:ListAccountSettings",
      "ecs:ListServices",
      "ecs:ListTagsForResource",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask",
      "ecs:StopTask",
      "ecs:TagResource",
      "ecs:UpdateService",
    ]
    resources = ["*"]
  }

  statement {
    sid = "Networking"
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRouteTables",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "PassTaskRoles"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.dagster_run.arn,
      aws_iam_role.dagster_task_execution.arn,
    ]
  }

  statement {
    sid = "RunLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.dagster_runs.arn}:*"]
  }

  statement {
    sid = "ReadAgentToken"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecrets",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ServiceDiscovery"
    actions = [
      "servicediscovery:CreateService",
      "servicediscovery:DeleteService",
      "servicediscovery:DeregisterInstance",
      "servicediscovery:GetNamespace",
      "servicediscovery:GetOperation",
      "servicediscovery:ListInstances",
      "servicediscovery:ListServices",
      "servicediscovery:ListTagsForResource",
      "servicediscovery:TagResource",
      "servicediscovery:UntagResource",
      "tag:GetResources",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "dagster_agent" {
  name   = "dagster-agent"
  role   = aws_iam_role.dagster_agent.id
  policy = data.aws_iam_policy_document.dagster_agent.json
}

# Run role: passed to ephemeral run tasks and long-running code-location
# servers. Grants access to the lake and catalog credentials.
resource "aws_iam_role" "dagster_run" {
  name               = "ducklake-dagster-run"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "dagster_run" {
  statement {
    sid = "LakeAccess"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.lake.arn,
      "${aws_s3_bucket.lake.arn}/*",
    ]
  }

  statement {
    sid       = "RDSIAMAuth"
    actions   = ["rds-db:connect"]
    resources = ["arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance.catalog.resource_id}/ducklake_admin"]
  }

  statement {
    sid       = "DescribeDB"
    actions   = ["rds:DescribeDBInstances"]
    resources = [aws_db_instance.catalog.arn]
  }
}

resource "aws_iam_role_policy" "dagster_run" {
  name   = "dagster-run"
  role   = aws_iam_role.dagster_run.id
  policy = data.aws_iam_policy_document.dagster_run.json
}
