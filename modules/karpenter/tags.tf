# Mark subnets and security group so Karpenter can discover cluster networking
resource "aws_ec2_tag" "karpenter_subnet_discovery" {
  count       = length(var.private_subnet_ids)
  resource_id = var.private_subnet_ids[count.index]
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_ec2_tag" "karpenter_sg_discovery" {
  resource_id = var.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
