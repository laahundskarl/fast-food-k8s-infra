# ===========================
# KUBERNETES INFRASTRUCTURE
# ===========================

# Data sources para recursos existentes
data "aws_vpc" "existing" {
  default = true
}

# Subnets específicas para o EKS
data "aws_subnet" "fastfood_subnet_1a" {
  id = "subnet-08d34ed68511f3917"  # us-east-1a
}

data "aws_subnet" "fastfood_subnet_1b" {
  id = "subnet-07fe020cefc4bd241"  # us-east-1b
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

# ===========================
# SECURITY GROUP RULES
# ===========================

# Security Group rule para permitir saída dos nodes EKS para RDS MySQL
resource "aws_security_group_rule" "eks_mysql_egress" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = module.eks.node_security_group_id
  security_group_id        = module.eks.node_security_group_id
  description              = "Allow EKS nodes to connect to RDS MySQL"
}

# ===========================
# LAMBDA FUNCTION
# ===========================

# Arquivo ZIP com código placeholder
data "archive_file" "lambda_placeholder" {
  type        = "zip"
  output_path = "${path.module}/lambda_placeholder.zip"
  source {
    content  = "exports.handler = async (event) => { return { statusCode: 200, body: 'Hello from Lambda!' }; };"
    filename = "index.js"
  }
}

# Função Lambda (usando LabRole existente)
resource "aws_lambda_function" "auth_lambda" {
  function_name = "fast-food-auth"
  role         = data.aws_iam_role.lambda_role.arn
  handler      = "index.handler"
  runtime      = "nodejs18.x"
  timeout      = 10
  filename     = data.archive_file.lambda_placeholder.output_path
  source_code_hash = data.archive_file.lambda_placeholder.output_base64sha256

  # Variáveis mínimas - serão sobrescritas pelo workflow deploy-lambda.yml
  environment {
    variables = {
      PLACEHOLDER = "configured-by-workflow"
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
    Component   = "serverless"
  }
}

# ===========================
# API GATEWAY
# ===========================

# API Gateway REST API
resource "aws_api_gateway_rest_api" "fast_food_api" {
  name = "fast-food-api"

  tags = {
    Environment = var.environment
    Terraform   = "true"
    Component   = "api-gateway"
  }
}

# API Gateway Resource for /auth
resource "aws_api_gateway_resource" "auth_resource" {
  rest_api_id = aws_api_gateway_rest_api.fast_food_api.id
  parent_id   = aws_api_gateway_rest_api.fast_food_api.root_resource_id
  path_part   = "auth"
}

# API Gateway Method POST /auth
resource "aws_api_gateway_method" "auth_post" {
  rest_api_id   = aws_api_gateway_rest_api.fast_food_api.id
  resource_id   = aws_api_gateway_resource.auth_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integration with Lambda
resource "aws_api_gateway_integration" "auth_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.fast_food_api.id
  resource_id = aws_api_gateway_resource.auth_resource.id
  http_method = aws_api_gateway_method.auth_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.auth_lambda.arn}/invocations"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "fast_food_api_deployment" {
  depends_on = [aws_api_gateway_integration.auth_lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.fast_food_api.id
  stage_name  = "prod"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.fast_food_api.execution_arn}/*/*"
}