data "archive_file" "lambda_registrations" {
  type        = "zip"
  source_dir  = "${path.module}/../registrations"
  output_path = "${path.module}/bin/registrations.zip"
}

# IAM Role for Registrations
resource "aws_iam_role" "lambda_registrations_exec_role" {
  name = "${var.project_name}-registrations-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

# Log group with configurable retention
resource "aws_cloudwatch_log_group" "registrations_logs" {
  name              = "/aws/lambda/${var.project_name}-registrations"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = var.common_tags
}

# CloudWatch Logs Policy
resource "aws_iam_policy" "registrations_logs_policy" {
  name        = "${var.project_name}-registrations-logs-policy"
  description = "Permissions for CloudWatch Logs for Registrations"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Effect = "Allow",
      Resource = [
        "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-registrations:*"
      ]
    }]
  })
}

# Cognito Policy
resource "aws_iam_policy" "registrations_cognito_policy" {
  name        = "${var.project_name}-registrations-cognito-policy"
  description = "Permissions for Cognito for Registrations"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "cognito-idp:SignUp",
        "cognito-idp:ConfirmSignUp",
        "cognito-idp:InitiateAuth",
        "cognito-idp:AdminInitiateAuth",
        "cognito-idp:AdminGetUser"
      ],
      Effect   = "Allow",
      Resource = aws_cognito_user_pool.main.arn
    }]
  })
}

# Lambda function Registrations
resource "aws_lambda_function" "registrations" {
  function_name    = "${var.project_name}-registrations"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_registrations_exec_role.arn
  filename         = data.archive_file.lambda_registrations.output_path
  source_code_hash = data.archive_file.lambda_registrations.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      LOG_LEVEL            = var.log_level
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.main.id
      COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.web.id
    }
  }

  tags       = var.common_tags
  depends_on = [aws_cloudwatch_log_group.registrations_logs]
}

# Attachments for Registrations
resource "aws_iam_role_policy_attachment" "registrations_logs_attach" {
  role       = aws_iam_role.lambda_registrations_exec_role.name
  policy_arn = aws_iam_policy.registrations_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "registrations_cognito_attach" {
  role       = aws_iam_role.lambda_registrations_exec_role.name
  policy_arn = aws_iam_policy.registrations_cognito_policy.arn
}

resource "aws_iam_role_policy_attachment" "registrations_vpc_attach" {
  role       = aws_iam_role.lambda_registrations_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "registrations_basic_execution" {
  role       = aws_iam_role.lambda_registrations_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}