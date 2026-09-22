# Grant the Jenkins IAM role the network path and EKS permissions it needs to
# manage the cluster from the automation server

# Open the EKS control plane's HTTPS port only from the Jenkins security group
resource "aws_security_group_rule" "jenkins_to_eks_control_plane" {
  description              = "Allow Jenkins to reach the EKS API server for terraform/kubectl/helm"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.cluster_security_group_id
  source_security_group_id = aws_security_group.jenkins.id
}

# Register the Jenkins instance role as an EKS access principal
resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.jenkins.arn
  type          = "STANDARD"
}

# Give the Jenkins role cluster-admin access for infrastructure automation
resource "aws_eks_access_policy_association" "jenkins_admin" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.jenkins.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jenkins]
}
