variable "aws_region" {
  description = "AWS region used for region-scoped lookups and policy resources"
  type        = string
}

variable "project" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to launch the instance in"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance in"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.small"
}

variable "jenkins_ssh_public_key" {
  description = "SSH public key for Jenkins EC2 access"
  type        = string
}

variable "admin_cidr" {
  description = "Admin IP allowed to access the Jenkins EC2 instance"
  type        = string
}

variable "terraform_state_bucket" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster Jenkins deploys to (grants it an EKS access entry)"
  type        = string
}

variable "cluster_security_group_id" {
  description = "EKS cluster's security group (grants Jenkins network access to the control plane's private endpoint)"
  type        = string
}
