# ============================================================================
# AMAZON MANAGED GRAFANA
# ============================================================================

# IAM Role for Grafana Workspace
resource "aws_iam_role" "grafana" {
  name = "${var.project_name}-${var.environment}-grafana-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "grafana.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

# Attach CloudWatch read-only policy to the Grafana role
resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# Amazon Managed Grafana Workspace
resource "aws_grafana_workspace" "main" {
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana.arn
  data_sources             = ["CLOUDWATCH"]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-workspace"
  })
}
