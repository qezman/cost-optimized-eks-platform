data "aws_caller_identity" "current" {}

module "vpc" {
  source = "../../modules/vpc"

  project              = var.project
  availability_zones   = var.availability_zones
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "eks" {
  source = "../../modules/eks"

  project            = var.project
  private_subnet_ids = module.vpc.private_subnet_ids
  cluster_version    = var.cluster_version
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  admin_cidr         = var.admin_cidr
}
