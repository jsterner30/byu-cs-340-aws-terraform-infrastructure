resource "aws_sqs_queue" "posts_queue" {
  name                       = "postsQueue"
  delay_seconds              = 0
  message_retention_seconds  = 34560
  receive_wait_time_seconds  = 0
  visibility_timeout_seconds = 60
}

resource "aws_sqs_queue" "jobs_queue" {
  name                       = "jobsQueue"
  delay_seconds              = 0
  message_retention_seconds  = 34560
  receive_wait_time_seconds  = 0
  visibility_timeout_seconds = 60
}

resource "aws_iam_policy" "sqs_access" {
  name = "sqs-full-access"
  path = "/"

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect   = "Allow",
        Action   = "sqs:*",
        Resource = "arn:aws:sqs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "queue_full_access" {
  policy_arn = aws_iam_policy.sqs_access.arn
  role       = aws_iam_role.lambda_role.name
}

resource "aws_lambda_function" "follow_fetcher" {
  function_name = "followFetcher"
  filename      = "../lambda/zip/lambda/nodejs.zip" # Path to your Lambda function code
  handler       = "lambda/followFetcherLambda.handler"
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

resource "aws_lambda_function" "job_handler" {
  function_name = "jobHandler"
  filename      = "../lambda/zip/lambda/nodejs.zip" # Path to your Lambda function code
  handler       = "lambda/jobHandlerLambda.handler"
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

resource "aws_lambda_event_source_mapping" "job_handler_trigger" {
  event_source_arn = aws_sqs_queue.jobs_queue.arn
  function_name    = aws_lambda_function.job_handler.arn
}

resource "aws_lambda_event_source_mapping" "follow_fetcher_trigger" {
  event_source_arn = aws_sqs_queue.posts_queue.arn
  function_name    = aws_lambda_function.follow_fetcher.arn
}

output "posts_queue_url" {
  value = aws_sqs_queue.posts_queue.id
}


output "jobs_queue_url" {
  value = aws_sqs_queue.jobs_queue.id
}

