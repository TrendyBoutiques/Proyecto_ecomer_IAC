
# ============================================================================
# AWS WAF V2
# ============================================================================

variable "waf_managed_rules" {
  description = "Map of managed rule groups to enable"
  type = map(object({
    priority = number
  }))
  default = {
    "AWSManagedRulesCommonRuleSet"          = { priority = 10 }
    "AWSManagedRulesAmazonIpReputationList" = { priority = 20 }
    "AWSManagedRulesKnownBadInputsRuleSet"  = { priority = 30 }
    "AWSManagedRulesSQLiRuleSet"            = { priority = 40 }
  }
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  provider    = aws.waf_region
  name        = "${var.project_name}-${var.environment}-waf"
  description = "WAF for ${var.project_name} CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Reglas administradas por AWS
  dynamic "rule" {
    for_each = var.waf_managed_rules
    content {
      name     = rule.key
      priority = rule.value.priority
      override_action {
        none {}
      }
      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-waf"
  })
}



# Output
output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}
