data "aws_caller_identity" "current" {}

module "vpc" {
  source = "../../modules/vpc"

  project              = var.project
  availability_zones   = var.availability_zones
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
}
