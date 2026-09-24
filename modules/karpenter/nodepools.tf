# EC2 node class Karpenter uses to launch worker instances
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      instanceProfile = aws_iam_instance_profile.karpenter_node.name

      amiSelectorTerms = [
        { alias = "al2@latest" }
      ]

      subnetSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.cluster_name } }
      ]

      securityGroupSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.cluster_name } }
      ]
    }
  })
  depends_on = [helm_release.karpenter]
}

# Node pool for low-cost EC2 instances and spot/on-demand mix
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "default" }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot", "on-demand"] },
            { key = "karpenter.k8s.aws/instance-family", operator = "In", values = ["t3", "t3a"] },
            { key = "node.kubernetes.io/instance-type", operator = "In", values = ["t3.micro", "t3.small", "t3.medium", "t3a.micro", "t3a.small", "t3a.medium"] }
          ]
        }
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
        expireAfter         = "720h"
      }
    }
  })
  depends_on = [helm_release.karpenter, kubectl_manifest.karpenter_node_class]
}
