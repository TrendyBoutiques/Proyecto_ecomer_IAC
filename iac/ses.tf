
# ============================================================================
# AMAZON SES - SIMPLE EMAIL SERVICE
# ============================================================================

variable "ses_email_identity" {
  description = "Email address to use as the sender identity in SES"
  type        = string
  default     = "noreply@example.com" # Reemplazar con tu email
}

# SES Email Identity
resource "aws_ses_domain_identity" "main" {
  domain = split("@", var.ses_email_identity)[1]
}

# Política de IAM para que la Lambda send-emails-order pueda usar SES
resource "aws_iam_policy" "lambda_ses_policy" {
  name        = "${var.project_name}-${var.environment}-lambda-ses-policy"
  description = "Allows Lambda to send emails via SES"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        # Limitar al ARN de la identidad de SES para mayor seguridad
        Resource = aws_ses_domain_identity.main.arn
      }
    ]
  })

  tags = var.common_tags
}

# Adjuntar la política al rol de la Lambda de envío de correos
resource "aws_iam_role_policy_attachment" "send_emails_order_ses_attach" {
  role       = aws_iam_role.lambda_send_emails_order_exec_role.name
  policy_arn = aws_iam_policy.lambda_ses_policy.arn
}

# Output
output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.main.arn
}

output "ses_domain_identity_verification_token" {
  description = "DNS token for domain verification"
  value       = aws_ses_domain_identity.main.verification_token
  sensitive   = true
}
