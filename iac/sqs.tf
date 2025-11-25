
# ============================================================================
# SQS - SIMPLE QUEUE SERVICE
# ============================================================================

# Cola para procesar compras iniciadas desde el carrito
resource "aws_sqs_queue" "purchase_queue" {
  name                      = "${var.project_name}-purchase-queue"
  delay_seconds             = 0
  max_message_size          = 2048  # 2KB
  message_retention_seconds = 86400 # 1 day
  receive_wait_time_seconds = 10

  tags = var.common_tags
}

# Cola para enviar notificaciones de órdenes por correo
resource "aws_sqs_queue" "send_emails_order_queue" {
  name                      = "${var.project_name}-send-emails-order-queue"
  delay_seconds             = 0
  max_message_size          = 2048  # 2KB
  message_retention_seconds = 86400 # 1 day
  receive_wait_time_seconds = 10

  tags = var.common_tags
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "purchase_queue_url" {
  description = "URL de la cola de compras"
  value       = aws_sqs_queue.purchase_queue.url
}

output "purchase_queue_arn" {
  description = "ARN de la cola de compras"
  value       = aws_sqs_queue.purchase_queue.arn
}

output "send_emails_order_queue_url" {
  description = "URL de la cola de notificación de órdenes"
  value       = aws_sqs_queue.send_emails_order_queue.url
}

output "send_emails_order_queue_arn" {
  description = "ARN de la cola de notificación de órdenes"
  value       = aws_sqs_queue.send_emails_order_queue.arn
}
