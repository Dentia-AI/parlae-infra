variable "profile" {
  description = "AWS CLI profile to use for the dev environment."
  type        = string
  default     = "parlae"
}

variable "region" {
  description = "AWS region for dev resources."
  type        = string
  default     = "us-east-2"
}

variable "domain" {
  description = "Root Route53 domain."
  type        = string
  default     = "parlae.ca"
}

variable "cognito_google_client_id" {
  description = "Google OAuth client ID for the Cognito IdP."
  type        = string
}

variable "cognito_google_client_secret" {
  description = "Google OAuth client secret for the Cognito IdP."
  type        = string
  sensitive   = true
}

# Aurora
variable "aurora_master_password" {
  description = "Aurora master password. Sensitive — do not commit to VCS."
  type        = string
  sensitive   = true
}

# Stripe
variable "stripe_publishable_key" {
  description = "Stripe publishable key (use test key for dev)."
  type        = string
  sensitive   = true
}

variable "stripe_secret_key" {
  description = "Stripe secret key (use test key for dev)."
  type        = string
  sensitive   = true
}

variable "stripe_webhook_secret" {
  description = "Stripe webhook signing secret."
  type        = string
  sensitive   = true
  default     = ""
}

# Backend service secrets
variable "sikka_app_id" {
  description = "Sikka system-level App ID."
  type        = string
  sensitive   = true
}

variable "sikka_app_key" {
  description = "Sikka system-level App Key."
  type        = string
  sensitive   = true
}

variable "vapi_api_key" {
  description = "Vapi API key for backend."
  type        = string
  sensitive   = true
}

variable "vapi_webhook_secret" {
  description = "Vapi webhook signature verification secret."
  type        = string
  sensitive   = true
}

variable "twilio_account_sid" {
  description = "Twilio Account SID."
  type        = string
  sensitive   = true
}

variable "twilio_auth_token" {
  description = "Twilio Auth Token."
  type        = string
  sensitive   = true
}

variable "twilio_messaging_service_sid" {
  description = "Twilio Messaging Service SID."
  type        = string
  default     = ""
}
