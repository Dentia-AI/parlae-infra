variable "profile" {
  description = "AWS CLI profile to use for the dev environment."
  type        = string
  default     = "dentia"
}

variable "region" {
  description = "AWS region for dev resources."
  type        = string
  default     = "us-east-2"
}

variable "domain" {
  description = "Root Route53 domain."
  type        = string
  default     = "dentiaapp.com"
}

variable "cognito_google_client_id" {
  description = "Google OAuth client ID for the Cognito IdP."
  type        = string
  # Value should be set in terraform.tfvars (not committed to git)
}

variable "cognito_google_client_secret" {
  description = "Google OAuth client secret for the Cognito IdP."
  type        = string
  sensitive   = true
  # Value should be set in terraform.tfvars (not committed to git)
}
