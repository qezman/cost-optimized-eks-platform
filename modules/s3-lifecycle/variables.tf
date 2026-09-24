variable "project" {
  description = "Project name used as prefix on all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}