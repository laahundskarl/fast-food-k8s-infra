# IAM Role para a Lambda
resource "aws_iam_role" "lambda_auth_role" {
  name = "lambda-auth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy para logs básicos
resource "aws_iam_role_policy_attachment" "lambda_auth_basic" {
  role       = aws_iam_role.lambda_auth_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy para acessar RDS (se necessário)
resource "aws_iam_role_policy" "lambda_rds_policy" {
  name = "lambda-rds-policy"
  role = aws_iam_role.lambda_auth_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# Data source para obter informações do RDS
data "aws_db_instance" "fastfood_db" {
  db_instance_identifier = "fastfood-db"
}

# Arquivo ZIP com código placeholder
data "archive_file" "lambda_placeholder" {
  type        = "zip"
  output_path = "${path.module}/lambda_placeholder.zip"
  source {
    content  = "exports.handler = async (event) => { return { statusCode: 200, body: 'Hello from Lambda!' }; };"
    filename = "index.js"
  }
}

# Função Lambda
resource "aws_lambda_function" "auth_lambda" {
  function_name = "fast-food-auth"
  role         = aws_iam_role.lambda_auth_role.arn
  handler      = "index.handler"
  runtime      = "nodejs18.x"
  timeout      = 10
  filename     = data.archive_file.lambda_placeholder.output_path
  source_code_hash = data.archive_file.lambda_placeholder.output_base64sha256

  environment {
    variables = {
      NODE_ENV = "dev"
      
      # DATABASE - usando mesmas configurações do K8s
      DATABASE_HOST      = data.aws_db_instance.fastfood_db.address
      DATABASE_PORT      = "3306"
      DATABASE_USER      = "admin"
      DATABASE_PASS      = "admin123"
      DATABASE_ROOT_PASS = "root123"
      DATABASE_NAME      = "fastfood"
      DATABASE_URL       = "mysql://admin:admin123@${data.aws_db_instance.fastfood_db.address}:3306/fastfood?allowPublicKeyRetrieval=true"
      MIGRATE_DATABASE_URL = "mysql://admin:admin123@${data.aws_db_instance.fastfood_db.address}:3306/fastfood?allowPublicKeyRetrieval=true"
      PORT = "3000"
      
      # JWT
      JWT_SECRET = "jwt_secret_key"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_auth_basic]
}