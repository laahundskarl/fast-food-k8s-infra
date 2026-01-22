# ===========================
# KUBERNETES INFRASTRUCTURE
# ===========================

# Data sources para recursos existentes
data "aws_vpc" "existing" {
  default = true
}

# Subnets específicas para o EKS
data "aws_subnet" "fastfood_subnet_1a" {
  id = "subnet-0e257caab709de070"  # us-east-1a
}

data "aws_subnet" "fastfood_subnet_1b" {
  id = "subnet-07ab87725b03df0e8"  # us-east-1b
}

# Lista das subnets para o EKS
locals {
  eks_subnet_ids = [
    data.aws_subnet.fastfood_subnet_1a.id,  # us-east-1a
    data.aws_subnet.fastfood_subnet_1b.id,  # us-east-1b
  ]
}

# Para compatibilidade com o módulo EKS
data "aws_subnets" "default" {
  filter {
    name   = "subnet-id"
    values = local.eks_subnet_ids
  }
}

# IAM Roles existentes
data "aws_iam_role" "eks_cluster_role" {
  name = "LabRole"
}

data "aws_iam_role" "eks_node_role" {
  name = "LabRole"
}

# IAM Role existente para Lambda (mesmo LabRole usado pelo EKS)
data "aws_iam_role" "lambda_role" {
  name = "LabRole"
}

# Data source para buscar o security group dos nodes EKS criado no db-infra
data "aws_security_group" "eks_nodes" {
  filter {
    name   = "tag:Name"
    values = ["fastfood-eks-nodes-security-group"]
  }
  filter {
    name   = "tag:Component"
    values = ["kubernetes"]
  }
}

# ===========================
# EKS CLUSTER
# ===========================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = data.aws_vpc.existing.id
  subnet_ids                     = data.aws_subnets.default.ids
  cluster_endpoint_public_access = true

  # IAM roles
  create_iam_role = false
  iam_role_arn    = data.aws_iam_role.eks_cluster_role.arn

  # Desabilitar OIDC Provider (não permitido no voclabs)
  enable_irsa = false

  # EKS Addons para storage
  cluster_addons = {
    aws-ebs-csi-driver = {
      version = "v1.14.1-eksbuild.1"  # Versão mais estável
      resolve_conflicts = "OVERWRITE"
    }
  }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = [var.node_instance_type]
  }

  eks_managed_node_groups = {
    default = {
      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size

      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"

      # Use existing IAM role
      create_iam_role = false
      iam_role_arn    = data.aws_iam_role.eks_node_role.arn

      # Adicionar o security group do db-infra aos nodes
      vpc_security_group_ids = [
        data.aws_security_group.eks_nodes.id
      ]
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
    Component   = "kubernetes"
  }
}

# ===========================
# ECR REPOSITORY
# ===========================

resource "aws_ecr_repository" "fastfood_api" {
  name         = var.ecr_repository_name
  force_delete = var.ecr_force_delete

  tags = {
    Name = var.ecr_repository_name
    ManagedBy = "terraform"
    Component = "container-registry"
    Environment = var.environment
  }
}

