data "archive_file" "lambda_orderandshipping" {
  type        = "zip"
  source_dir  = "${path.module}/../orderandshipping"
  output_path = "${path.module}/bin/orderandshipping.zip"
}

# IAM Role para Order and Shipping
resource "aws_iam_role" "lambda_orderandshipping_exec_role" {
  name = "${var.project_name}-orderandshipping-exec-role"

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

# Grupo de logs con retención configurable
resource "aws_cloudwatch_log_group" "orderandshipping_logs" {
  name              = "/aws/lambda/${var.project_name}-orderandshipping"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = var.common_tags
}

# Política para CloudWatch Logs
resource "aws_iam_policy" "orderandshipping_logs_policy" {
  name        = "${var.project_name}-orderandshipping-logs-policy"
  description = "Permisos para CloudWatch Logs de Order and Shipping"

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
        "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-orderandshipping:*"
      ]
    }]
  })
}

# Política para DynamoDB - ACTUALIZADA para incluir todas las tablas necesarias
resource "aws_iam_policy" "orderandshipping_dynamodb_policy" {
  name        = "${var.project_name}-orderandshipping-dynamodb-policy"
  description = "Permisos para DynamoDB de Order and Shipping"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem"
      ],
      Effect = "Allow",
      Resource = [
        aws_dynamodb_table.orders_table.arn,
        "${aws_dynamodb_table.orders_table.arn}/index/*",
        aws_dynamodb_table.order_items_table.arn,
        "${aws_dynamodb_table.order_items_table.arn}/index/*",
        aws_dynamodb_table.shipping_table.arn,
        "${aws_dynamodb_table.shipping_table.arn}/index/*",
        aws_dynamodb_table.products_table.arn,
        "${aws_dynamodb_table.products_table.arn}/index/*"
      ]
    }]
  })
}

# Política para SES (mantenida por si decides usarla después)
resource "aws_iam_policy" "orderandshipping_ses_policy" {
  name        = "${var.project_name}-orderandshipping-ses-policy"
  description = "Permisos para SES de Order and Shipping"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

# Lambda function Order and Shipping - ACTUALIZADA
resource "aws_lambda_function" "orderandshipping" {
  function_name    = "${var.project_name}-orderandshipping"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_orderandshipping_exec_role.arn
  filename         = data.archive_file.lambda_orderandshipping.output_path
  source_code_hash = data.archive_file.lambda_orderandshipping.output_base64sha256
  timeout          = 60  # Mayor timeout para procesamiento de órdenes
  memory_size      = 512 # Mayor memoria para procesamiento de órdenes

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      # Tablas DynamoDB
      ORDERS_TABLE      = aws_dynamodb_table.orders_table.name
      ORDER_ITEMS_TABLE = aws_dynamodb_table.order_items_table.name
      SHIPPING_TABLE    = aws_dynamodb_table.shipping_table.name
      PRODUCTS_TABLE    = aws_dynamodb_table.products_table.name
      # NUEVO: Cola SQS para enviar notificaciones de email
      SEND_EMAILS_ORDER_QUEUE_URL = aws_sqs_queue.send_emails_order_queue.url
      # Configuración
      LOG_LEVEL = var.log_level
      REGION    = var.aws_region
    }
  }

  tags       = var.common_tags
  depends_on = [aws_cloudwatch_log_group.orderandshipping_logs]
}

# Attachments para Order and Shipping
resource "aws_iam_role_policy_attachment" "orderandshipping_logs_attach" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = aws_iam_policy.orderandshipping_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "orderandshipping_dynamodb_attach" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = aws_iam_policy.orderandshipping_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "orderandshipping_ses_attach" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = aws_iam_policy.orderandshipping_ses_policy.arn
}

# NUEVO: Attachment para política SQS

resource "aws_iam_policy" "orderandshipping_sqs_policy" {
  name        = "${var.project_name}-orderandshipping-sqs-policy"
  description = "Permisos para enviar mensajes a la cola SQS de notificación de ordenes"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "sqs:SendMessage",
      Effect   = "Allow",
      Resource = aws_sqs_queue.send_emails_order_queue.arn
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "orderandshipping_sqs_attach" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = aws_iam_policy.orderandshipping_sqs_policy.arn
}

# VPC Access
resource "aws_iam_role_policy_attachment" "orderandshipping_vpc_attach" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "orderandshipping_basic_execution" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "orderandshipping_function_name" {
  description = "Nombre de la función Lambda OrderAndShipping"
  value       = aws_lambda_function.orderandshipping.function_name
}

output "orderandshipping_function_arn" {
  description = "ARN de la función Lambda OrderAndShipping"
  value       = aws_lambda_function.orderandshipping.arn
}

output "orderandshipping_role_arn" {
  description = "ARN del rol IAM de OrderAndShipping"
  value       = aws_iam_role.lambda_orderandshipping_exec_role.arn
}