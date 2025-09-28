data "archive_file" "lambda_zip_file" {
  type        = "zip"
  source_file = "C:/Users/Balaji/Lambda_Terraform/index.js"
  output_path = "C:/Users/Balaji/Lambda_Terraform/index.zip"
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = file("lambda-policy.json")

}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

}

resource "aws_lambda_function" "lambda_demo" {
  filename         = "C:/Users/Balaji/Lambda_Terraform/index.zip"
  function_name    = "lambda_demo"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 30
  source_code_hash = data.archive_file.lambda_zip_file.output_base64sha256

  environment {
    variables = {
      VIDEO_NAME = "Lambda Terraform Demo"

    }

  }
}

resource "aws_api_gateway_rest_api" "api" {
  name        = "api"
  description = "Creating API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "api_resource" {
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "demo-path"
  rest_api_id = aws_api_gateway_rest_api.api.id

}

resource "aws_api_gateway_method" "api_method" {
  resource_id   = aws_api_gateway_resource.api_resource.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  http_method   = "POST"
  authorization = "NONE"

}

resource "aws_api_gateway_integration" "api_integration" {
  http_method             = aws_api_gateway_method.api_method.http_method
  resource_id             = aws_api_gateway_resource.api_resource.id
  rest_api_id             = aws_api_gateway_rest_api.api.id
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_demo.invoke_arn
}

resource "aws_api_gateway_deployment" "api_deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.api_resource.id,
      aws_api_gateway_method.api_method.id,
      aws_api_gateway_integration.api_integration.id,
      aws_api_gateway_rest_api.api.body
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.api_integration]

}
resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.api_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "dev"
}

resource "aws_lambda_permission" "api_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_demo.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"

}


