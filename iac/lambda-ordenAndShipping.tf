# Cambiar TODOS los nombres de "ordenes" a "orderandshipping"

# Archivo de la Lambda (antes lambda-ordenes.tf, ahora lambda-orderandshipping.tf)

data "archive_file" "lambda_orderandshipping" {
  type        = "zip"
  source_dir  = "${path.module}/../orderandshipping"  # También cambiar nombre de carpeta
  output_path = "${path.module}/bin/orderandshipping.zip"
}

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

resource "aws_cloudwatch_log_group" "orderandshipping_logs" {
  name              = "/aws/lambda/${var.project_name}-orderandshipping"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = var.common_tags
}

resource "aws_iam_policy" "orderandshipping_logs_policy" {
  name        = "${var.project_name}-orderandshipping-logs-policy"
  description = "Permisos para CloudWatch Logs de la lambda de Order and Shipping"

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

resource "aws_iam_policy" "orderandshipping_dynamodb_policy" {
  name        = "${var.project_name}-orderandshipping-dynamodb-policy"
  description = "Permisos para DynamoDB de la lambda de Order and Shipping"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      Effect = "Allow",
      Resource = [
        aws_dynamodb_table.orders_table.arn,
        "${aws_dynamodb_table.orders_table.arn}/index/*",
        aws_dynamodb_table.shipping_table.arn,
        "${aws_dynamodb_table.shipping_table.arn}/index/*"
      ]
    }]
  })
}

resource "aws_lambda_function" "orderandshipping" {
  function_name    = "${var.project_name}-orderandshipping"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_orderandshipping_exec_role.arn
  filename         = data.archive_file.lambda_orderandshipping.output_path
  source_code_hash = data.archive_file.lambda_orderandshipping.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ORDERS_TABLE   = aws_dynamodb_table.orders_table.name
      SHIPPING_TABLE = aws_dynamodb_table.shipping_table.name
      LOG_LEVEL      = var.log_level
    }
  }

  tags       = var.common_tags
  depends_on = [aws_cloudwatch_log_group.orderandshipping_logs]
}

resource "aws_iam_role_policy_attachment" "orderandshipping_logs_attach" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = aws_iam_policy.orderandshipping_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "orderandshipping_dynamodb_attach" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = aws_iam_policy.orderandshipping_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "orderandshipping_vpc_attach" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "orderandshipping_basic_execution" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}