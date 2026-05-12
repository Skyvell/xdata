# -----------------------------------------------------------------------------
# Networking (from the networking module)
# -----------------------------------------------------------------------------

variable "region" {
  type        = string
  description = "AWS region. Used for CloudWatch awslogs config and IAM ARN construction."
}

variable "vpc_id" {
  type        = string
  description = "VPC the Dagster security group and service discovery namespace attach to."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets the agent service and code-location/run tasks launch into."
}

# -----------------------------------------------------------------------------
# Ducklake (from the ducklake module)
# -----------------------------------------------------------------------------

variable "catalog_sg_id" {
  type        = string
  description = "Catalog security group id. An ingress rule is added so Dagster tasks can reach Postgres."
}

variable "catalog_resource_id" {
  type        = string
  description = "RDS resource id of the catalog. Used to scope the rds-db:connect IAM policy."
}

variable "catalog_arn" {
  type        = string
  description = "RDS ARN of the catalog. Used to scope the rds:DescribeDBInstances IAM policy."
}

variable "lake_bucket_arn" {
  type        = string
  description = "ARN of the S3 lake bucket. Used to scope run-role S3 access."
}

# -----------------------------------------------------------------------------
# Dagster
# -----------------------------------------------------------------------------

variable "dagster_org_slug" {
  type        = string
  description = "Dagster+ subdomain prefix — everything before .dagster.plus in your UI URL (e.g. 'tedskyvell.eu')."
}

variable "dagster_deployment" {
  type        = string
  description = "Dagster+ deployment to connect to."
  default     = "prod"
}

variable "dagster_agent_image" {
  type        = string
  description = "Container image for the Dagster Cloud agent. Pin to a specific version, never :latest."
  default     = "public.ecr.aws/dagster/dagster-cloud-agent:1.13.4"
}

variable "dagster_agent_token_secret_name" {
  type        = string
  description = "Name of the Secrets Manager secret holding the Dagster+ agent token. Must be created out-of-band before apply."
  default     = "ducklake/dagster-cloud-agent-token"
}

variable "dagster_agent_cpu" {
  type        = number
  description = "Fargate CPU units for the Dagster agent task."
  default     = 256
}

variable "dagster_agent_memory" {
  type        = number
  description = "Fargate memory (MiB) for the Dagster agent task."
  default     = 1024
}

variable "dagster_agent_replicas" {
  type        = number
  description = "Number of Dagster agent replicas. 1 is fine for dev; prod should run 2."
  default     = 1
}

variable "dagster_server_cpu" {
  type        = string
  description = "Default Fargate CPU units for code-location server tasks the agent launches."
  default     = "512"
}

variable "dagster_server_memory" {
  type        = string
  description = "Default Fargate memory (MiB) for code-location server tasks."
  default     = "1024"
}

variable "dagster_run_cpu" {
  type        = string
  description = "Default Fargate CPU units for run tasks the agent launches per materialization."
  default     = "1024"
}

variable "dagster_run_memory" {
  type        = string
  description = "Default Fargate memory (MiB) for run tasks."
  default     = "2048"
}

# -----------------------------------------------------------------------------
# Tagging
# -----------------------------------------------------------------------------

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources in this module."
  default     = {}
}
