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

# Função Lambda
resource "aws_lambda_function" "auth_lambda" {
  function_name = "fast-food-auth"
  role         = aws_iam_role.lambda_auth_role.arn
  handler      = "index.handler"
  runtime      = "nodejs18.x"
  timeout      = 10

  depends_on = [aws_iam_role_policy_attachment.lambda_auth_basic]
}