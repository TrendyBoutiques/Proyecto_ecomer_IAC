# 1. Empaquetado del código
# Asumimos que el código fuente de órdenes está en ../ordenes
data "archive_file" "lambda_ordenes" {
  type        = "zip"
  source_dir  = "${path.module}/../ordenes" 
  output_path = "${path.module}/bin/ordenes.zip"
}

# 2. IAM Role específico para la Lambda de Ordenes
resource "aws_iam_role" "lambda_ordenes_exec_role" {
  name = "${var.project_name}-ordenes-exec-role"

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

# 3. Grupo de logs en CloudWatch
resource "aws_cloudwatch_log_group" "ordenes_logs" {
  name              = "/aws/lambda/${var.project_name}-ordenes"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = var.common_tags
}

# 4. Políticas IAM
# Política para escribir logs
resource "aws_iam_policy" "ordenes_logs_policy" {
  name        = "${var.project_name}-ordenes-logs-policy"
  description = "Permisos para CloudWatch Logs de la lambda de Ordenes"

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
        "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-ordenes:*"
      ]
    }]
  })
}

# Política para acceder a DynamoDB (Tabla de Órdenes)
resource "aws_iam_policy" "ordenes_dynamodb_policy" {
  name        = "${var.project_name}-ordenes-dynamodb-policy"
  description = "Permisos para DynamoDB de la lambda de Ordenes"

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
        # Usamos interpolación directa o referenciamos el output si estuviera en módulo
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-orders",
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-orders/index/*"
      ]
    }]
  })
}

# 5. Definición de la Función Lambda
resource "aws_lambda_function" "ordenes" {
  function_name    = "${var.project_name}-ordenes"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_ordenes_exec_role.arn
  filename         = data.archive_file.lambda_ordenes.output_path
  source_code_hash = data.archive_file.lambda_ordenes.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ORDERS_TABLE = "${var.project_name}-orders"
      LOG_LEVEL    = var.log_level
    }
  }

  tags       = var.common_tags
  depends_on = [aws_cloudwatch_log_group.ordenes_logs]
}

# 6. Attachments (Vincular políticas al rol)
resource "aws_iam_role_policy_attachment" "ordenes_logs_attach" {
  role       = aws_iam_role.lambda_ordenes_exec_role.name
  policy_arn = aws_iam_policy.ordenes_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "ordenes_dynamodb_attach" {
  role       = aws_iam_role.lambda_ordenes_exec_role.name
  policy_arn = aws_iam_policy.ordenes_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "ordenes_vpc_attach" {
  role       = aws_iam_role.lambda_ordenes_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ordenes_basic_execution" {
  role       = aws_iam_role.lambda_ordenes_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
output "lambda_ordenes_arn" {
  description = "ARN de la función Lambda de Ordenes"
  value       = aws_lambda_function.ordenes.arn
}