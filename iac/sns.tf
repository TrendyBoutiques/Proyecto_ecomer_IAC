# ============================================================================
# SNS TOPIC FOR EMAIL NOTIFICATIONS
# ============================================================================

resource "aws_sns_topic" "email_notifications" {
  name = "${var.project_name}-${var.environment}-email-notifications"
  tags = var.common_tags
}

resource "aws_sns_topic_subscription" "email_queue_subscription" {
  topic_arn = aws_sns_topic.email_notifications.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.email_queue.arn
}

resource "aws_sqs_queue_policy" "email_queue_sns_policy" {
  queue_url = aws_sqs_queue.email_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowSNS",
        Effect = "Allow",
        Principal = {
          Service = "sns.amazonaws.com"
        },
        Action   = "sqs:SendMessage",
        Resource = aws_sqs_queue.email_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.email_notifications.arn
          }
        }
      }
    ]
  })
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for email notifications"
  value       = aws_sns_topic.email_notifications.arn
}
