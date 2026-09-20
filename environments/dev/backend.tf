terraform {
  backend "s3" {
    bucket       = "cost-optimization-platform-tfstate-722965867897"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
