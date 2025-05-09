

resource "terraform_data" "pip-install" {
  triggers_replace = {
    shell_hash = "${sha256(file("${path.module}/lambda/requirements.txt"))}"
  }

  provisioner "local-exec" {
    command = "python3 -m pip install -r lambda/requirements.txt -t ${path.module}/layer/python"
  }
}

data "archive_file" "code" {
  type        = "zip"
  source_dir  = "lambda"
  output_path = "lambda/converter.zip"
}

data "archive_file" "layer" {
  type        = "zip"
  source_dir  = "${path.module}/layer"
  output_path = "${path.module}/layer.zip"
  depends_on  = [terraform_data.pip-install]
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = file("lambda-policy.json")
}

resource "aws_iam_role_policy_attachment" "lambda_exec_role_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_layer_version" "layer" {
  layer_name          = "test-layer"
  filename            = data.archive_file.layer.output_path
  source_code_hash    = data.archive_file.layer.output_base64sha256
  compatible_runtimes = ["python3.9", "python3.10"]
}

resource "aws_lambda_function" "converter" {
  function_name    = "converter"
  role             = aws_iam_role.lambda_role.arn
  handler          = "converter.lambda_handler"
  runtime          = "python3.10"
  filename         = data.archive_file.code.output_path
  timeout          = 30
  source_code_hash = data.archive_file.code.output_base64sha256
  layers           = [aws_lambda_layer_version.layer.arn]

  #   environment {
  #     variables = {
  #       S3_BUCKET_NAME = aws_s3_bucket.converter_bucket.bucket
  #     }
  #   }

  depends_on = [aws_iam_role_policy_attachment.lambda_exec_role_attachment]

}

resource "aws_api_gateway_rest_api" "converter_api" {
  name        = "converter_api"
  description = "API for the converter Lambda function"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

}

resource "aws_api_gateway_resource" "converter_api_resource" {
  rest_api_id = aws_api_gateway_rest_api.converter_api.id
  parent_id   = aws_api_gateway_rest_api.converter_api.root_resource_id
  path_part   = "converter"
}

resource "aws_api_gateway_method" "converter_name" {
  rest_api_id   = aws_api_gateway_rest_api.converter_api.id
  resource_id   = aws_api_gateway_resource.converter_api_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "converter_integration" {
  rest_api_id             = aws_api_gateway_rest_api.converter_api.id
  resource_id             = aws_api_gateway_resource.converter_api_resource.id
  http_method             = aws_api_gateway_method.converter_name.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.converter.invoke_arn
}

# custom response
# resource "aws_api_gateway_method_response" "converter_response" {
#   rest_api_id = aws_api_gateway_rest_api.converter_api.id
#   resource_id = aws_api_gateway_resource.converter_api_resource.id
#   http_method = aws_api_gateway_method.converter_name.http_method
#   status_code = "200"

#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Origin" = true
#     "method.response.header.Access-Control-Allow-Headers" = true
#     "method.response.header.Access-Control-Allow-Methods" = true
#   }
# }

# resource "aws_api_gateway_integration_response" "converter_integration_response" {
#   rest_api_id = aws_api_gateway_rest_api.converter_api.id
#   resource_id = aws_api_gateway_resource.converter_api_resource.id
#   http_method = aws_api_gateway_method.converter_name.http_method
#   status_code = aws_api_gateway_method_response.converter_response.status_code

#   response_templates = {
#     "application/json" = jsonencode({ "LambdaValue" : "$input.path('$').body", "data" = "Custom Response" })
#   }
# }

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.converter_api.id
  depends_on = [
    aws_api_gateway_integration.converter_integration,
  ]

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.converter_api_resource.id,
      aws_api_gateway_method.converter_name.id,
      aws_api_gateway_integration.converter_integration.id,
      #   aws_api_gateway_method_response.converter_response.id,
      #   aws_api_gateway_integration_response.converter_integration_response.id,
    ]))

  }
}

resource "aws_api_gateway_stage" "dev_stage" {
  stage_name    = "dev"
  rest_api_id   = aws_api_gateway_rest_api.converter_api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  description   = "Development stage for the converter API"
}

resource "aws_lambda_permission" "apigw_converter_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.converter.function_name
  principal     = "apigateway.amazonaws.com"

  # The source ARN for the API Gateway
  source_arn = "${aws_api_gateway_rest_api.converter_api.execution_arn}/*/*"
}

output "invoke_url" {
  value = "${aws_api_gateway_rest_api.converter_api.execution_arn}/${aws_api_gateway_stage.dev_stage.stage_name}/converter"
}

output "lambda_function_name" {
  value = aws_lambda_function.converter.function_name
}
output "lambda_function_arn" {
  value = aws_lambda_function.converter.arn
}
output "invoke_url2" {
  value = aws_api_gateway_deployment.api_deployment.invoke_url
}