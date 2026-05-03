data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "compute_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:Skyvell/xdata:environment:${var.env}"]
    }
  }
}

resource "aws_iam_role" "compute" {
  name               = "xdata-compute-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.compute_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "compute_lake" {
  statement {
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.lake.arn,
      "${aws_s3_bucket.lake.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "compute_lake" {
  name   = "lake-access"
  role   = aws_iam_role.compute.id
  policy = data.aws_iam_policy_document.compute_lake.json
}
