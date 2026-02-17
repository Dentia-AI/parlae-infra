##########################
# Cognito configuration  #
##########################

locals {
  google_idp_enabled   = var.cognito_google_client_id != "" && var.cognito_google_client_secret != ""
  cognito_domain_value = local.cognito_custom_domain_enabled ? var.cognito_custom_domain : try(aws_cognito_user_pool_domain.default[0].domain, "${local.project_id}-auth")
}

resource "aws_acm_certificate" "cognito" {
  count             = local.cognito_custom_domain_enabled ? 1 : 0
  provider          = aws.use1
  domain_name       = var.cognito_custom_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.tags_common, {
    Name = "${local.project_id}-cognito-auth-cert"
  })
}

resource "aws_route53_record" "cognito_cert_validation" {
  for_each = local.cognito_custom_domain_enabled ? {
    for dvo in aws_acm_certificate.cognito[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
      zone   = lookup(local.host_zone_map, dvo.domain_name, var.domain)
    }
  } : {}

  zone_id         = data.aws_route53_zone.domains[each.value.zone].zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cognito" {
  count                   = local.cognito_custom_domain_enabled ? 1 : 0
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.cognito[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cognito_cert_validation : r.fqdn]
}

resource "aws_cognito_user_pool" "main" {
  name                     = "${local.project_id}-user-pool"
  alias_attributes         = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  tags = merge(local.tags_common, { Name = "${local.project_id}-user-pool" })

}

resource "aws_cognito_user_pool_domain" "default" {
  count        = local.cognito_custom_domain_enabled ? 0 : 1
  domain       = "${local.project_id}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_user_pool_domain" "custom" {
  count        = local.cognito_custom_domain_enabled ? 1 : 0
  domain       = var.cognito_custom_domain
  user_pool_id = aws_cognito_user_pool.main.id

  certificate_arn = aws_acm_certificate_validation.cognito[0].certificate_arn
}

resource "aws_route53_record" "cognito_custom_domain" {
  count   = local.cognito_custom_domain_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.domains[local.cognito_custom_domain_zone].zone_id
  name    = var.cognito_custom_domain
  type    = "CNAME"
  ttl     = 300
  records = [aws_cognito_user_pool_domain.custom[0].cloudfront_distribution]
}

resource "aws_cognito_user_pool_client" "frontend" {
  name                                 = "${local.project_id}-frontend-client"
  user_pool_id                         = aws_cognito_user_pool.main.id
  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  supported_identity_providers         = local.google_idp_enabled ? ["COGNITO", "Google"] : ["COGNITO"]

  callback_urls = [
    "https://${var.alb_hostname}/api/auth/callback/cognito"
  ]
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]
  logout_urls = [
    "https://${var.alb_hostname}"
  ]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  lifecycle {
    ignore_changes = [generate_secret]
  }
}

resource "aws_cognito_identity_provider" "google" {
  count         = local.google_idp_enabled ? 1 : 0
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  attribute_mapping = {
    email          = "email"
    email_verified = "email_verified"
    name           = "name"
    given_name     = "given_name"
    family_name    = "family_name"
    picture        = "picture"
  }

  provider_details = {
    authorize_scopes = "openid email profile"
    client_id        = var.cognito_google_client_id
    client_secret    = var.cognito_google_client_secret
  }
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.frontend.id
}

output "cognito_client_secret" {
  value     = aws_cognito_user_pool_client.frontend.client_secret
  sensitive = true
}

output "cognito_domain" {
  value = local.cognito_domain_value
}
