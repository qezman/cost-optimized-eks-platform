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

module "workloads" {
  source = "../../modules/workloads"

  namespace = var.namespace
  replicas  = var.replicas

  depends_on = [module.eks]
}

module "jenkins" {
  source = "../../modules/jenkins"

  project                   = var.project
  environment               = var.environment
  admin_cidr                = var.admin_cidr
  jenkins_ssh_public_key    = var.jenkins_ssh_public_key
  vpc_id                    = module.vpc.vpc_id
  cluster_name              = module.eks.cluster_name
  subnet_id                 = module.vpc.public_subnet_ids[0]
  cluster_security_group_id = module.eks.cluster_security_group_id
  terraform_state_bucket    = var.terraform_state_bucket
  aws_region                = var.aws_region
}

module "karpenter" {
  source = "../../modules/karpenter"

  project                   = var.project
  environment               = var.environment
  cluster_endpoint          = module.eks.cluster_endpoint
  cluster_name              = module.eks.cluster_name
  cluster_oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  private_subnet_ids        = module.vpc.private_subnet_ids
  cluster_security_group_id = module.eks.cluster_security_group_id

  depends_on = [module.eks]
}
