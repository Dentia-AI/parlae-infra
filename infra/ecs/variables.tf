variable "region" {
  type    = string
  default = "us-east-2"
}

variable "profile" {
  type    = string
  default = "parlae"
}

variable "project_name" {
  type    = string
  default = "parlae"
}

variable "domain" {
  description = "Root domain managed in Route53 (e.g., parlae.ca)."
  type        = string
  default     = "parlae.ca"
}

variable "alb_hostname" {
  description = "Hostname for the app served by the ALB (e.g., app.parlae.ca)."
  type        = string
  default     = "app.parlae.ca"
}

variable "additional_cert_names" {
  description = "Optional extra names on the cert (e.g., api.parlae.ca)."
  type        = list(string)
  default     = ["api.parlae.ca"]
}

# Additional domains for Parlae
variable "additional_domains" {
  description = "Additional apex domains managed in Route53 that should resolve to this ALB (e.g., parlae.ca)."
  type        = list(string)
  default = [
    # Add any additional domains here if needed
  ]
}

variable "app_subdomain" {
  description = "Subdomain used for the authenticated application host."
  type        = string
  default     = "app"
}

variable "marketing_subdomain" {
  description = "Subdomain used for the marketing host."
  type        = string
  default     = "www"
}

variable "api_subdomain" {
  description = "Subdomain used for the public API/backend host."
  type        = string
  default     = "api"
}

variable "include_apex_domains" {
  description = "If true, create alias records for the apex of each domain so it resolves to the ALB."
  type        = bool
  default     = true
}

variable "cognito_google_client_id" {
  description = "Google OAuth client ID for the Cognito identity provider (leave blank to disable)."
  type        = string
  default     = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
}

variable "cognito_google_client_secret" {
  description = "Google OAuth client secret for the Cognito identity provider (leave blank to disable)."
  type        = string
  default     = "GOCSPX-YOUR_GOOGLE_CLIENT_SECRET"
  sensitive   = true
}

variable "cognito_custom_domain" {
  description = "Optional custom domain for the Cognito hosted UI (e.g., auth.example.com). Leave blank to use the AWS-provided domain."
  type        = string
  default     = ""  # Disabled for initial setup - use AWS-provided domain
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "environment" {
  type        = string
  description = "Environment name (prod|dev|preview-*)"
  default     = "prod"
  validation {
    condition     = can(regex("^(prod|dev|preview[-a-z0-9]*)$", var.environment))
    error_message = "environment must be prod, dev, or preview-*"
  }
}

variable "protect_prod" {
  type        = bool
  description = "Enable lifecycle.prevent_destroy on production resources"
  default     = true
}

variable "aurora_db_name" {
  description = "Aurora database name."
  type        = string
  default     = "dentia"
}

variable "aurora_master_username" {
  description = "Aurora master username."
  type        = string
  default     = "dentia_admin"
}

variable "aurora_master_password" {
  description = "Aurora master password. Sensitive — do not commit to VCS."
  type        = string
  sensitive   = true
}

variable "aurora_min_capacity" {
  type        = number
  description = "Minimum Aurora Serverless v2 capacity in ACUs (0.5 increments)."
  default     = 0.5
}

variable "aurora_max_capacity" {
  type        = number
  description = "Maximum Aurora Serverless v2 capacity in ACUs."
  default     = 8
}

variable "alert_emails" {
  description = "Email addresses to subscribe to infrastructure alerts."
  type        = list(string)
  default     = ["admin@parlae.ca"]
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for sending alerts (optional). Leave empty to disable Slack notifications."
  type        = string
  default     = ""
  sensitive   = true
}

variable "aurora_capacity_utilization_threshold" {
  description = "Percentage (0-1) of max Aurora capacity that should trigger an alarm."
  type        = number
  default     = 0.8
}

variable "ecs_max_tasks_threshold" {
  description = "Percentage (0-1) of max ECS tasks that should trigger an alarm."
  type        = number
  default     = 0.9
}

variable "frontend_max_tasks" {
  description = "Maximum number of frontend tasks that can be scaled to."
  type        = number
  default     = 8
}

variable "backend_max_tasks" {
  description = "Maximum number of backend tasks that can be scaled to."
  type        = number
  default     = 8
}

variable "frontend_alb_request_count_target" {
  description = "Target number of requests per target for frontend ALB-based auto-scaling (per 1-min period)."
  type        = number
  default     = 1000
}

variable "backend_alb_request_count_target" {
  description = "Target number of requests per target for backend ALB-based auto-scaling (per 1-min period)."
  type        = number
  default     = 1000
}

variable "frontend_db_connection_limit" {
  description = "Prisma connection pool size per frontend ECS task. Total connections = this * frontend_max_tasks."
  type        = number
  default     = 10
}

variable "backend_db_connection_limit" {
  description = "Prisma connection pool size per backend ECS task. Total connections = this * backend_max_tasks."
  type        = number
  default     = 20
}

# Stripe Configuration
variable "stripe_publishable_key" {
  description = "Stripe publishable key (use test key for dev, live key for production)"
  type        = string
  sensitive   = true
}

variable "stripe_secret_key" {
  description = "Stripe secret key (use test key for dev, live key for production)"
  type        = string
  sensitive   = true
}

variable "stripe_webhook_secret" {
  description = "Stripe webhook signing secret"
  type        = string
  sensitive   = true
  default     = ""
}

# ==================================================================
# Backend Service Secrets
# ==================================================================

variable "sikka_app_id" {
  description = "Sikka system-level App ID (shared across all practices)"
  type        = string
  sensitive   = true
}

variable "sikka_app_key" {
  description = "Sikka system-level App Key (shared across all practices)"
  type        = string
  sensitive   = true
}

variable "vapi_api_key" {
  description = "Vapi API key for backend"
  type        = string
  sensitive   = true
}

variable "vapi_webhook_secret" {
  description = "Vapi webhook signature verification secret"
  type        = string
  sensitive   = true
}

variable "retell_api_key" {
  description = "Retell AI API key for backup voice provider"
  type        = string
  sensitive   = true
  default     = ""
}

variable "retell_webhook_secret" {
  description = "Retell AI webhook signature secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "twilio_account_sid" {
  description = "Twilio Account SID"
  type        = string
  sensitive   = true
}

variable "twilio_auth_token" {
  description = "Twilio Auth Token"
  type        = string
  sensitive   = true
}

variable "twilio_messaging_service_sid" {
  description = "Twilio Messaging Service SID"
  type        = string
  default     = ""
}

# ==================================================================
# AWS SES Email Configuration
# ==================================================================

variable "aws_ses_access_key_id" {
  description = "AWS IAM Access Key ID for SES email sending"
  type        = string
  sensitive   = true
}

variable "aws_ses_secret_access_key" {
  description = "AWS IAM Secret Access Key for SES email sending"
  type        = string
  sensitive   = true
}

variable "email_from" {
  description = "Default sender email address (e.g. support@parlae.ca)"
  type        = string
  default     = "support@parlae.ca"
}

variable "email_from_name" {
  description = "Default sender display name"
  type        = string
  default     = "Parlae AI"
}

variable "mailer_provider" {
  description = "Email provider (aws-ses, smtp, etc.)"
  type        = string
  default     = "aws-ses"
}

# ==================================================================
# Google Calendar Configuration
# ==================================================================

variable "google_calendar_client_id" {
  description = "Google OAuth Client ID for Calendar API"
  type        = string
  sensitive   = true
}

variable "google_calendar_client_secret" {
  description = "Google OAuth Client Secret for Calendar API"
  type        = string
  sensitive   = true
}

variable "google_calendar_redirect_uri" {
  description = "Google OAuth redirect URI for Calendar callback"
  type        = string
  default     = ""
}
