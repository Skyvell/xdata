variable "region" {
  type        = string
  description = "AWS region. Used for CloudWatch awslogs config and IAM ARN construction."
}

variable "vpc_id" {
  type        = string
  description = "VPC where the runner security group is created."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets where scheduled Fargate tasks launch."
}

variable "catalog_sg_id" {
  type        = string
  description = "DuckLake catalog security group id. An ingress rule is added so runner tasks can reach Postgres."
}

variable "catalog_resource_id" {
  type        = string
  description = "RDS resource id of the DuckLake catalog. Used to scope the rds-db:connect IAM policy."
}

variable "catalog_arn" {
  type        = string
  description = "RDS ARN of the DuckLake catalog. Used to scope the rds:DescribeDBInstances IAM policy."
}

variable "lake_bucket_name" {
  type        = string
  description = "Name of the S3 lake bucket. Exposed to the runner container as DUCKLAKE_BUCKET."
}

variable "lake_bucket_arn" {
  type        = string
  description = "ARN of the S3 lake bucket. Used to scope runner S3 access."
}

variable "image_tag" {
  type        = string
  description = "Container image tag pushed by CI, usually the git SHA."
}

variable "schedules" {
  type = map(object({
    schedule_expression = string
    command             = list(string)
  }))
  description = "Named EventBridge Scheduler schedules. Each schedule runs the shared runner image with its own container command override."
}

variable "task_cpu" {
  type        = number
  description = "Fargate CPU units for scheduled runner tasks."
  default     = 1024
}

variable "task_memory" {
  type        = number
  description = "Fargate memory (MiB) for scheduled runner tasks."
  default     = 2048
}

variable "assign_public_ip" {
  type        = bool
  description = "Whether scheduled Fargate tasks receive a public IP."
  default     = true
}

variable "alarm_actions" {
  type        = list(string)
  description = "SNS topic ARNs or other alarm actions for runner failure alarms."
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources in this module."
  default     = {}
}
