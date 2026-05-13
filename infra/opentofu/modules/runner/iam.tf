data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "runner_execution" {
  name               = "ducklake-runner-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "runner_execution_managed" {
  role       = aws_iam_role.runner_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "runner_execution_secrets" {
  statement {
    sid       = "ReadCatalogMasterSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.catalog_master_secret_arn]
  }

  statement {
    sid       = "DecryptCatalogMasterSecret"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "runner_execution_secrets" {
  name   = "ducklake-runner-secrets"
  role   = aws_iam_role.runner_execution.id
  policy = data.aws_iam_policy_document.runner_execution_secrets.json
}

resource "aws_iam_role" "runner_task" {
  name               = "ducklake-runner-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "runner_task" {
  statement {
    sid = "LakeAccess"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      var.lake_bucket_arn,
      "${var.lake_bucket_arn}/*",
    ]
  }

  statement {
    sid       = "RDSIAMAuth"
    actions   = ["rds-db:connect"]
    resources = ["arn:aws:rds-db:${var.region}:${data.aws_caller_identity.current.account_id}:dbuser:${var.catalog_resource_id}/metadata_admin"]
  }

  statement {
    sid       = "DescribeDB"
    actions   = ["rds:DescribeDBInstances"]
    resources = [var.catalog_arn]
  }
}

resource "aws_iam_role_policy" "runner_task" {
  name   = "ducklake-runner"
  role   = aws_iam_role.runner_task.id
  policy = data.aws_iam_policy_document.runner_task.json
}

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "ducklake-runner-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "scheduler" {
  statement {
    sid     = "RunTask"
    actions = ["ecs:RunTask"]
    resources = [
      aws_ecs_task_definition.runner.arn,
      "${aws_ecs_task_definition.runner.arn_without_revision}:*",
    ]
  }

  statement {
    sid     = "PassTaskRoles"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.runner_execution.arn,
      aws_iam_role.runner_task.arn,
    ]
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "run-ecs-task"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler.json
}
