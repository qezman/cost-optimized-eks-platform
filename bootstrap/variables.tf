variable "aws_region" {
  description = "AWS region for s3 bucket"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Unique S3 bucket name for Terraform state_bucket_name"
  type        = string
  default     = "cost-optimization-platform-tfstate-722965867897"
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "cost-optimization-Terraform-locks"
}
