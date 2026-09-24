# Karpenter controller deployment
resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "kube-system"
  create_namespace = false # kube-system already exists

  # OCI Helm charts use the registry URL directly in the chart field
  chart   = "oci://public.ecr.aws/karpenter/karpenter"
  version = "1.0.1"

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = "karpenter"
        annotations = {
          # IRSA: let the controller assume the AWS role created above
          "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller.arn
        }
      }
      settings = {
        clusterName       = var.cluster_name
        clusterEndpoint   = var.cluster_endpoint
        interruptionQueue = aws_sqs_queue.main.name
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy.karpenter_controller,
    aws_eks_access_entry.karpenter_node
  ]
}
