# 1. Empaquetado del código
data "archive_file" "lambda_purchase_confirmation" {
  type        = "zip"
  source_dir  = "${path.module}/../purchase-confirmation"
  output_path = "${path.module}/bin/purchase-confirmation.zip"
}

# 2. IAM Role
resource "aws_iam_role" "lambda_purchase_confirmation_role" {
  name = "${var.project_name}-purchase-conf-role"

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

# 3. CloudWatch Logs
resource "aws_cloudwatch_log_group" "purchase_confirmation_logs" {
  name              = "/aws/lambda/${var.project_name}-purchase-confirmation"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = var.common_tags
}

# 4. Lambda Function
resource "aws_lambda_function" "purchase_confirmation" {
  function_name    = "${var.project_name}-purchase-confirmation"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_purchase_confirmation_role.arn
  filename         = data.archive_file.lambda_purchase_confirmation.output_path
  source_code_hash = data.archive_file.lambda_purchase_confirmation.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      LOG_LEVEL             = var.log_level
      # He corregido el nombre de la tabla para que coincida con dynamodb.tf
      ORDERS_TABLE = aws_dynamodb_table.orders_table.name
      STRIPE_WEBHOOK_SECRET = var.stripe_webhook_secret
      
      # Si tienes un archivo sns.tf, descomenta esta línea:
      # SNS_TOPIC_ARN         = aws_sns_topic.email_notifications.arn
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags       = var.common_tags
  depends_on = [aws_cloudwatch_log_group.purchase_confirmation_logs]
}

# 5. IAM Policy
resource "aws_iam_policy" "lambda_purchase_confirmation_policy" {
  name        = "${var.project_name}-purchase-conf-policy"
  description = "Policy for the Purchase Confirmation Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "${aws_cloudwatch_log_group.purchase_confirmation_logs.arn}:*"
      },
      {
        Effect = "Allow",
        Action = ["dynamodb:UpdateItem", "dynamodb:PutItem", "dynamodb:Query", "dynamodb:GetItem"],
        # Referencia corregida a la tabla 'orders'
        Resource = [
            aws_dynamodb_table.orders_table.arn,
            "${aws_dynamodb_table.orders_table.arn}/index/*"
        ]
      },
      {
        # Permisos para VPC (Network Interfaces)
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Resource = "*"
      }
      # Si tienes SNS creado, añade este bloque de nuevo:
      # {
      #   Effect   = "Allow",
      #   Action   = "sns:Publish",
      #   Resource = aws_sns_topic.email_notifications.arn
      # }
    ]
  })
}

# 6. Attach policy to role
resource "aws_iam_role_policy_attachment" "purchase_confirmation_policy_attach" {
  role       = aws_iam_role.lambda_purchase_confirmation_role.name
  policy_arn = aws_iam_policy.lambda_purchase_confirmation_policy.arn
}