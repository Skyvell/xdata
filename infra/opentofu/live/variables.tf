variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "eu-north-1"
}

variable "metadata_instance_class" {
  type        = string
  description = "RDS instance class for the metadata database."
  default     = "db.t4g.micro"
}

variable "metadata_multi_az" {
  type        = bool
  description = "Enable Multi-AZ for the metadata RDS instance."
  default     = false
}

variable "metadata_backup_retention_period" {
  type        = number
  description = "Number of days to retain automated RDS backups. 0 disables backups."
  default     = 0
}

variable "metadata_skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot when the metadata RDS instance is destroyed."
  default     = true
}

variable "metadata_deletion_protection" {
  type        = bool
  description = "Enable deletion protection on the metadata RDS instance."
  default     = false
}

variable "metadata_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed inbound on the metadata RDS port."
  default     = []
}

variable "runner_image_tag" {
  type        = string
  description = "Container image tag for the scheduled runner. Updated by CI on each push."
  default     = "latest"
}
