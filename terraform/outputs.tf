# ===========================
# KUBERNETES INFRASTRUCTURE OUTPUTS
# ===========================

# ECR Outputs
output "ecr_repository_url" {
  description = "URL do repositório ECR"
  value       = aws_ecr_repository.fastfood_api.repository_url
}

output "ecr_repository_arn" {
  description = "ARN do repositório ECR"
  value       = aws_ecr_repository.fastfood_api.arn
}

output "ecr_repository_name" {
  description = "Nome do repositório ECR"
  value       = aws_ecr_repository.fastfood_api.name
}

# EKS Cluster Outputs
output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Versão do cluster EKS"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "ID do security group do cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security Group ID dos nodes EKS"
  value       = module.eks.node_security_group_id
}

output "cluster_arn" {
  description = "ARN do cluster EKS"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Certificate authority data do cluster"
  value       = module.eks.cluster_certificate_authority_data
}

# Network Outputs
output "vpc_id" {
  description = "ID da VPC"
  value       = data.aws_vpc.existing.id
}

output "eks_subnet_ids" {
  description = "IDs das subnets usadas pelo EKS"
  value       = local.eks_subnet_ids
}

# Additional outputs for integration
output "node_groups" {
  description = "EKS node groups"
  value       = module.eks.eks_managed_node_groups
}

output "oidc_provider_arn" {
  description = "ARN do OIDC provider"
  value       = module.eks.oidc_provider_arn
}