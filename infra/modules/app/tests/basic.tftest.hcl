mock_provider "aws" {}

run "plan_succeeds" {
  command = plan
}
