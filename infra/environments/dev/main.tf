terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

module "ecs" {
  source = "../../ecs"

  environment                  = "dev"
  project_name                 = "parlae"
  region                       = var.region
  profile                      = var.profile
  domain                       = var.domain
  alb_hostname                 = "dev.${var.domain}"
  additional_cert_names        = []
  additional_domains           = []
  app_subdomain                = "app"
  marketing_subdomain          = "www"
  include_apex_domains         = false
  protect_prod                 = false
  cognito_google_client_id     = var.cognito_google_client_id
  cognito_google_client_secret = var.cognito_google_client_secret
  cognito_custom_domain        = ""

  # Aurora
  aurora_master_password = var.aurora_master_password

  # Stripe
  stripe_publishable_key = var.stripe_publishable_key
  stripe_secret_key      = var.stripe_secret_key
  stripe_webhook_secret  = var.stripe_webhook_secret

  # Backend service secrets
  sikka_app_id                 = var.sikka_app_id
  sikka_app_key                = var.sikka_app_key
  vapi_api_key                 = var.vapi_api_key
  vapi_webhook_secret          = var.vapi_webhook_secret
  twilio_account_sid           = var.twilio_account_sid
  twilio_auth_token            = var.twilio_auth_token
  twilio_messaging_service_sid = var.twilio_messaging_service_sid
}

output "dev_outputs" {
  value     = module.ecs
  sensitive = true
}
