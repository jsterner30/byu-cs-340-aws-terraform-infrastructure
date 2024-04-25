resource "aws_dynamodb_table" "user" {
  name           = "user"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "alias"
  attribute {
    name = "alias"
    type = "S"
  }
}

resource "aws_dynamodb_table" "feed" {
  name           = "feed"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "alias"
  range_key      = "timestamp"
  attribute {
    name = "alias"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "N"
  }
}

resource "aws_dynamodb_table" "story" {
  name           = "story"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "alias"
  range_key      = "timestamp"
  attribute {
    name = "alias"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "N"
  }
}

resource "aws_dynamodb_table" "token" {
  name           = "token"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "tokenString"
  range_key      = "alias"
  attribute {
    name = "tokenString"
    type = "S"
  }
  attribute {
    name = "alias"
    type = "S"
  }
  global_secondary_index {
    name            = "aliasIndex"
    hash_key        = "alias"
    range_key       = "tokenString"
    write_capacity  = 1
    read_capacity   = 1
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expiration"
    enabled        = true
  }
}

resource "aws_dynamodb_table" "follow" {
  name           = "follow"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "followerAlias"
  range_key      = "followeeAlias"
  attribute {
    name = "followerAlias"
    type = "S"
  }
  attribute {
    name = "followeeAlias"
    type = "S"
  }
  global_secondary_index {
    name            = "followsIndex"
    hash_key        = "followeeAlias"
    range_key       = "followerAlias"
    write_capacity  = 1
    read_capacity   = 1
    projection_type = "ALL"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "dynamo_request" {
  name = "tweeter-dynamo-request"
  path = "/"

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:BatchWriteItem"
        ],
        Resource : "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/*",
        Effect : "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamo_request" {
  policy_arn = aws_iam_policy.dynamo_request.arn
  role       = aws_iam_role.lambda_role.name
}
