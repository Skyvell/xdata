variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "eu-north-1"
}

variable "catalog_instance_class" {
  type        = string
  description = "RDS instance class for the catalog database."
  default     = "db.t4g.micro"
}

variable "catalog_multi_az" {
  type        = bool
  description = "Enable Multi-AZ for the catalog RDS instance."
  default     = false
}

variable "catalog_backup_retention_period" {
  type        = number
  description = "Number of days to retain automated RDS backups. 0 disables backups."
  default     = 0
}

variable "catalog_skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot when the catalog RDS instance is destroyed."
  default     = true
}

variable "catalog_deletion_protection" {
  type        = bool
  description = "Enable deletion protection on the catalog RDS instance."
  default     = false
}

variable "catalog_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed inbound on the catalog RDS port."
  default     = []
}

variable "dagster_org_slug" {
  type        = string
  description = "Dagster+ subdomain prefix — everything before .dagster.plus in your UI URL (e.g. 'tedskyvell.eu')."
}

variable "dagster_deployment" {
  type        = string
  description = "Dagster+ deployment to connect to. Default 'prod' is the deployment Dagster+ auto-creates on signup."
  default     = "prod"
}

variable "dagster_agent_image" {
  type        = string
  description = "Container image for the Dagster Cloud agent."
  default     = "public.ecr.aws/dagster/dagster-cloud-agent:1.13.4"
}

variable "dagster_agent_token_secret_name" {
  type        = string
  description = "Secrets Manager secret name holding the Dagster+ agent token."
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
  description = "Number of Dagster agent replicas."
  default     = 1
}
