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

variable "alb_request_count_target" {
  description = "Target number of requests per target for ALB-based auto-scaling."
  type        = number
  default     = 1000
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
