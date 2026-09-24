variable "project" {
  description = "Project name used as prefix on all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "EKS cluster Jenkins deploys to (grants it an EKS access entry)"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL used for IRSA trust policy"
  type        = string
}

variable "cluster_endpoint" {
  description = "The API server endpoint URL for the EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets Karpenter can place nodes in"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "Security group used by cluster networking"
  type        = string
}
