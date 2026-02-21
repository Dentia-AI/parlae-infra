# =============================================================================
# Amazon SES Configuration
# =============================================================================

# SES Domain Identity
resource "aws_ses_domain_identity" "main" {
  domain = var.domain
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# Account-level suppression list (auto-suppresses bounced/complained addresses)
resource "aws_sesv2_account_suppression_attributes" "main" {
  suppressed_reasons = ["BOUNCE", "COMPLAINT"]
}

# =============================================================================
# SNS Topics for SES Bounce & Complaint Notifications
# =============================================================================

resource "aws_sns_topic" "ses_bounces" {
  name = "${local.project_id}-ses-bounces"
  tags = local.tags
}

resource "aws_sns_topic" "ses_complaints" {
  name = "${local.project_id}-ses-complaints"
  tags = local.tags
}

# Email subscriptions (confirm via email after apply)
resource "aws_sns_topic_subscription" "ses_bounces_email" {
  topic_arn = aws_sns_topic.ses_bounces.arn
  protocol  = "email"
  endpoint  = "support@${var.domain}"
}

resource "aws_sns_topic_subscription" "ses_complaints_email" {
  topic_arn = aws_sns_topic.ses_complaints.arn
  protocol  = "email"
  endpoint  = "support@${var.domain}"
}

# Wire SES domain identity to SNS topics
resource "aws_ses_identity_notification_topic" "bounces" {
  topic_arn                = aws_sns_topic.ses_bounces.arn
  notification_type        = "Bounce"
  identity                 = aws_ses_domain_identity.main.domain
  include_original_headers = true
}

resource "aws_ses_identity_notification_topic" "complaints" {
  topic_arn                = aws_sns_topic.ses_complaints.arn
  notification_type        = "Complaint"
  identity                 = aws_ses_domain_identity.main.domain
  include_original_headers = true
}

# SNS topic policy: allow SES to publish to bounce/complaint topics
resource "aws_sns_topic_policy" "ses_bounces" {
  arn = aws_sns_topic.ses_bounces.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSESPublish"
        Effect    = "Allow"
        Principal = { Service = "ses.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.ses_bounces.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_policy" "ses_complaints" {
  arn = aws_sns_topic.ses_complaints.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSESPublish"
        Effect    = "Allow"
        Principal = { Service = "ses.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.ses_complaints.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}
