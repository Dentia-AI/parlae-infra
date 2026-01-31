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
  project_name                 = "dentia"
  region                       = var.region
  profile                      = var.profile
  domain                       = var.domain
  alb_hostname                 = "app.${var.domain}"
  additional_cert_names        = []
  additional_domains           = ["dentia.ca", "dentia.co", "dentia.app"]
  app_subdomain                = "app"
  marketing_subdomain          = "www"
  include_apex_domains         = true
  protect_prod                 = false
  cognito_google_client_id     = var.cognito_google_client_id
  cognito_google_client_secret = var.cognito_google_client_secret
  cognito_custom_domain        = ""
}

output "dev_outputs" {
  value     = module.ecs
  sensitive = true
}
