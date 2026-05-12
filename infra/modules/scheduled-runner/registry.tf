resource "aws_ecr_repository" "runner" {
  name                 = "ducklake-runner"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}
