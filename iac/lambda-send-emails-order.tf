
# ============================================================================
# IAM ROLE PARA LAMBDA DE ENVÍO DE CORREOS
# ============================================================================

# Rol para la Lambda que envía correos de notificación de órdenes
resource "aws_iam_role" "lambda_send_emails_order_exec_role" {
  name = "${var.project_name}-send-emails-order-exec-role"

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
