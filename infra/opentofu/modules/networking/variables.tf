variable "region" {
  type        = string
  description = "AWS region. Used to build the S3 gateway endpoint service name."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources in this module."
  default     = {}
}
