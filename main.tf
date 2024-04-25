provider "aws" {
  region = "us-west-2"
}

# List of Lambda function names, their corresponding handler functions, endpoints, and descriptions
variable "lambda_functions" {
  default = [
    { name = "tweeter-server-followLambda", handler = "lambda/followLambda.handler", endpoint = "follow", description = "Allows the user to follow another user" },
    { name = "tweeter-server-getFolloweeCountLambda", handler = "lambda/getFolloweeCountLambda.handler", endpoint = "followeecount", description = "Returns the number of followees for the user" },
    { name = "tweeter-server-getFolloweesLambda", handler = "lambda/getFolloweesLambda.handler", endpoint = "followees", description = "Returns a page of followees for a user" },
    { name = "tweeter-server-getFollowerCountLambda", handler = "lambda/getFollowerCountLambda.handler", endpoint = "followercount", description = "Returns the number of followers for the user" },
    { name = "tweeter-server-getIsFollowerStatusLamda", handler = "lambda/getIsFollowerStatusLamda.handler", endpoint = "isfollower", description = "Returns whether another user follows the user" },
    { name = "tweeter-server-getMoreFeedsLambda", handler = "lambda/getMoreFeedsLambda.handler", endpoint = "feed", description = "Returns feed items to the user" },
    { name = "tweeter-server-getMoreFollowersLambda", handler = "lambda/getMoreFollowersLambda.handler", endpoint = "followers", description = "Returns a page of followers for a user" },
    { name = "tweeter-server-getMoreStoriesLambda", handler = "lambda/getMoreStoriesLambda.handler", endpoint = "stories", description = "Returns feed items to the user" },
    { name = "tweeter-server-getUserLambda", handler = "lambda/getUserLambda.handler", endpoint = "user", description = "Returns a user" },
    { name = "tweeter-server-loginLambda", handler = "lambda/loginLambda.handler", endpoint = "login", description = "Logs the user in with the specified username and password" },
    { name = "tweeter-server-logoutLambda", handler = "lambda/logoutLambda.handler", endpoint = "logout", description = "Logs the user out" },
    { name = "tweeter-server-postStatusLambda", handler = "lambda/postStatusLambda.handler", endpoint = "poststatus", description = "Allows the user to post a status" },
    { name = "tweeter-server-registerLambda", handler = "lambda/registerLambda.handler", endpoint = "register", description = "Registers the user in with the specified username, password, firstname, lastname, and image" },
    { name = "tweeter-server-unfollowLambda", handler = "lambda/unfollowLambda.handler", endpoint = "unfollow", description = "Allows the user to unfollow another user" }
  ]
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # Example of policies to attach (modify as needed)
  # Here, I'm attaching a policy that grants Lambda basic execution permissions
  inline_policy {
    name = "lambda_execution_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }]
    })
  }
}

# Create Lambda functions
resource "aws_lambda_function" "lambda" {
  count         = length(var.lambda_functions)
  function_name = var.lambda_functions[count.index].name
  filename      = "../lambda/zip/lambda/nodejs.zip" # Path to your Lambda function code
  handler       = var.lambda_functions[count.index].handler
  runtime       = "nodejs20.x"

  layers = [aws_lambda_layer_version.deps_layer.arn]
  role   = aws_iam_role.lambda_role.arn

  timeout     = 60
  memory_size = 2048
  environment {
    variables = {
      key = "value"
    }
  }

  source_code_hash = filebase64sha256("../lambda/zip/lambda/nodejs.zip") # forces terraform to push the zip files when they change
}

# Create Lambda layers
resource "aws_lambda_layer_version" "deps_layer" {
  filename            = "../lambda/zip/deps/nodejs.zip"
  layer_name          = "tweeter-deps"
  compatible_runtimes = ["nodejs20.x"]
  source_code_hash    = filebase64sha256("../lambda/zip/deps/nodejs.zip") # forces terraform to push the zip files when they change
}


resource "aws_api_gateway_rest_api" "tweeter_api_gateway" {
  name        = "tweeter-api-gateway"
  description = "tweeter-api-gateway"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  parent_id   = aws_api_gateway_rest_api.tweeter_api_gateway.root_resource_id
  path_part   = "service"
}

module "root_cors" {
  source          = "squidfunk/api-gateway-enable-cors/aws"
  version         = "0.3.3"
  api_id          = aws_api_gateway_rest_api.tweeter_api_gateway.id
  api_resource_id = aws_api_gateway_resource.root.id
}

resource "aws_api_gateway_resource" "endpoint" {
  count       = length(var.lambda_functions)
  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  parent_id   = aws_api_gateway_resource.root.id
  path_part   = var.lambda_functions[count.index].endpoint
}

module "cors" {
  count   = length(var.lambda_functions)
  source  = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.tweeter_api_gateway.id
  api_resource_id = aws_api_gateway_resource.endpoint[count.index].id
}

resource "aws_api_gateway_method" "endpoint_methods" {
  count         = length(var.lambda_functions)
  rest_api_id   = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id   = aws_api_gateway_resource.endpoint[count.index].id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "method_response_200" {
  count       = length(var.lambda_functions)
  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id = aws_api_gateway_resource.endpoint[count.index].id
  http_method = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "method_response_400" {
  count       = length(var.lambda_functions)
  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id = aws_api_gateway_resource.endpoint[count.index].id
  http_method = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code = "400"

  response_models = {
    "application/json" = "Error"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "method_response_403" {
  count       = length(var.lambda_functions)
  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id = aws_api_gateway_resource.endpoint[count.index].id
  http_method = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code = "403"

  response_models = {
    "application/json" = "Error"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "method_response_404" {
  count       = length(var.lambda_functions)
  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id = aws_api_gateway_resource.endpoint[count.index].id
  http_method = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code = "404"

  response_models = {
    "application/json" = "Error"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "method_response_409" {
  count       = length(var.lambda_functions)
  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id = aws_api_gateway_resource.endpoint[count.index].id
  http_method = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code = "409"

  response_models = {
    "application/json" = "Error"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "method_response_500" {
  count       = length(var.lambda_functions)
  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id = aws_api_gateway_resource.endpoint[count.index].id
  http_method = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code = "500"

  response_models = {
    "application/json" = "Error"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "integration_response_200" {
  count       = length(var.lambda_functions)
  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id = aws_api_gateway_resource.endpoint[count.index].id
  http_method = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code = 200
  depends_on = [
    aws_api_gateway_method.endpoint_methods,
    aws_api_gateway_integration.lambda_integration
  ]

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "integration_response_400" {
  count             = length(var.lambda_functions)
  rest_api_id       = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id       = aws_api_gateway_resource.endpoint[count.index].id
  http_method       = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code       = 400
  selection_pattern = ".*\"status\":400.*"
  depends_on = [
    aws_api_gateway_method.endpoint_methods,
    aws_api_gateway_integration.lambda_integration
  ]

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "integration_response_403" {
  count             = length(var.lambda_functions)
  rest_api_id       = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id       = aws_api_gateway_resource.endpoint[count.index].id
  http_method       = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code       = 403
  selection_pattern = ".*\"status\":403.*"
  depends_on = [
    aws_api_gateway_method.endpoint_methods,
    aws_api_gateway_integration.lambda_integration
  ]

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "integration_response_404" {
  count             = length(var.lambda_functions)
  rest_api_id       = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id       = aws_api_gateway_resource.endpoint[count.index].id
  http_method       = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code       = 404
  selection_pattern = ".*\"status\":404.*"
  depends_on = [
    aws_api_gateway_method.endpoint_methods,
    aws_api_gateway_integration.lambda_integration
  ]

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "integration_response_409" {
  count             = length(var.lambda_functions)
  rest_api_id       = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id       = aws_api_gateway_resource.endpoint[count.index].id
  http_method       = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code       = 409
  selection_pattern = ".*\"status\":409.*"
  depends_on = [
    aws_api_gateway_method.endpoint_methods,
    aws_api_gateway_integration.lambda_integration
  ]

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "integration_response_500" {
  count             = length(var.lambda_functions)
  rest_api_id       = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id       = aws_api_gateway_resource.endpoint[count.index].id
  http_method       = aws_api_gateway_method.endpoint_methods[count.index].http_method
  status_code       = 500
  selection_pattern = ".*\"status\":500.*"
  depends_on = [
    aws_api_gateway_method.endpoint_methods,
    aws_api_gateway_integration.lambda_integration
  ]

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

resource "aws_api_gateway_documentation_part" "endpoint_documentation" {
  count       = length(var.lambda_functions)
  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  location {
    type   = "METHOD"
    method = aws_api_gateway_method.endpoint_methods[count.index].http_method
    path   = aws_api_gateway_resource.endpoint[count.index].path
  }
  properties = <<EOF
{
  "description": "${var.lambda_functions[count.index].description}"
}
EOF
}


resource "aws_api_gateway_integration" "lambda_integration" {
  count                   = length(var.lambda_functions)
  rest_api_id             = aws_api_gateway_rest_api.tweeter_api_gateway.id
  resource_id             = aws_api_gateway_resource.endpoint[count.index].id
  http_method             = aws_api_gateway_method.endpoint_methods[count.index].http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.lambda[count.index].invoke_arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_lambda_permission" "apigw_lambda" {
  count         = length(var.lambda_functions)
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda[count.index].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.tweeter_api_gateway.execution_arn}/*/POST/service/${var.lambda_functions[count.index].endpoint}"
}

output "api_url" {
  value = aws_api_gateway_deployment.deployment.invoke_url
}

resource "aws_api_gateway_documentation_version" "tweeter_documentation" {
  version     = "1.0.0"
  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  description = "Tweeter API Docs"
  depends_on = [
    aws_api_gateway_documentation_part.endpoint_documentation,
  ]
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_resource.root,
    aws_api_gateway_resource.endpoint,
    aws_api_gateway_method.endpoint_methods,
    aws_api_gateway_method_response.method_response_200,
    aws_api_gateway_integration_response.integration_response_200,
    aws_api_gateway_integration_response.integration_response_400,
    aws_api_gateway_integration_response.integration_response_500,
    aws_iam_role.lambda_role,
    aws_lambda_layer_version.deps_layer,
    aws_lambda_function.lambda,
    aws_api_gateway_rest_api.tweeter_api_gateway,
    module.root_cors,
    module.cors,
  ]

  rest_api_id = aws_api_gateway_rest_api.tweeter_api_gateway.id
  stage_name  = "dev"
}