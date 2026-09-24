data "aws_caller_identity" "current" {}

# EC2 node role used by Karpenter to launch worker instances
resource "aws_iam_role" "karpenter_node" {
  name = "${var.cluster_name}-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-karpenter-node-role"
  }
}

# Standard EKS/EC2 permissions for Karpenter-launched worker nodes
resource "aws_iam_role_policy_attachment" "node_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "node_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.karpenter_node.name
}

# Instance profile required by EC2 when creating nodes with this role
resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${var.cluster_name}-karpenter-node-profile"
  role = aws_iam_role.karpenter_node.name
}

# Allow dynamic EC2 nodes to register with the EKS cluster
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"
}

locals {
  oidc_provider = replace(var.cluster_oidc_issuer_url, "https://", "")
}

# IRSA role for the Karpenter controller service account
resource "aws_iam_role" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # Restrict token audience and subject to the Karpenter SA
            "${local.oidc_provider}:aud" = "sts.amazonaws.com"
            "${local.oidc_provider}:sub" = "system:serviceaccount:kube-system:karpenter"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-karpenter-controller-role"
  }
}

# Permissions required for node provisioning, discovery, and interruption handling
resource "aws_iam_role_policy" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller-policy"
  role = aws_iam_role.karpenter_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KarpenterFleetManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      {
        Sid    = "KarpenterDiscoveryAndPricing"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts",
          "ssm:GetParameter"
        ]
        Resource = "*"
      },
      {
        Sid    = "KarpenterPassRoleToNodes"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.karpenter_node.arn
      },
      {
        Sid    = "KarpenterInterruptionQueue"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
          "sqs:ReceiveMessage"
        ]
        Resource = aws_sqs_queue.main.arn
      },
      {
        Sid      = "KarpenterTagOnCreate"
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = "*"
      },
      {
        Sid      = "KarpenterServiceLinkedRole"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "spot.amazonaws.com"
          }
        }
      }
    ]
  })
}