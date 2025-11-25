# ============================================================================
# SQS QUEUE FOR EMAILS
# ============================================================================

# Dead Letter Queue for Emails
resource "aws_sqs_queue" "email_dlq" {
  name                      = "${var.project_name}-email-dlq"
  message_retention_seconds = var.sqs_dlq_message_retention

  tags = merge(
    var.common_tags,
    {
      Purpose = "Dead Letter Queue for Emails"
    }
  )
}

# Main queue for Emails
resource "aws_sqs_queue" "email_queue" {
  name                       = "${var.project_name}-email-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout_emails
  message_retention_seconds  = var.sqs_message_retention
  delay_seconds              = 0
  receive_wait_time_seconds  = var.sqs_receive_wait_time
  max_message_size           = 262144 # 256 KB

  # Dead Letter Queue configuration
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.email_dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = merge(
    var.common_tags,
    {
      Purpose = "Email Queue"
    }
  )
}

# ============================================================================
# IAM POLICY FOR EMAIL SQS (CONSUMER)
# ============================================================================

# Policy for Send Emails Order (Consumer)
resource "aws_iam_policy" "send_emails_sqs_policy" {
  name        = "${var.project_name}-send-emails-sqs-policy"
  description = "Permissions for Send Emails Lambda to receive messages from the queue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          aws_sqs_queue.email_queue.arn,
          aws_sqs_queue.email_dlq.arn
        ]
      }
    ]
  })

  tags = var.common_tags
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "email_queue_url" {
  description = "URL of the Email queue"
  value       = aws_sqs_queue.email_queue.url
}

output "email_queue_arn" {
  description = "ARN of the Email queue"
  value       = aws_sqs_queue.email_queue.arn
}

output "email_dlq_url" {
  description = "URL of the Email DLQ"
  value       = aws_sqs_queue.email_dlq.url
}

output "email_dlq_arn" {
  description = "ARN of the Email DLQ"
  value       = aws_sqs_queue.email_dlq.arn
}