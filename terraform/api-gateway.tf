# API Gateway REST API
resource "aws_api_gateway_rest_api" "fast_food_api" {
  name = "fast-food-api"
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
  function_name = var.lambda_auth_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.fast_food_api.execution_arn}/*/*"
}