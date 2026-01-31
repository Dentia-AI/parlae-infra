# Using Route53 zone defined in acm_alb.tf

locals {
  cf_expected_domains = local.is_prod ? distinct(compact(concat(
    [var.alb_hostname, var.domain],
    var.marketing_subdomain != "" ? ["${var.marketing_subdomain}.${var.domain}"] : [],
    var.additional_cert_names,
    var.additional_domains
  ))) : []
  cf_validation_map = local.is_prod ? {
    for dvo in aws_acm_certificate.cf[0].domain_validation_options :
    dvo.domain_name => dvo
  } : {}
}

#########################################
# ACM for CloudFront (must be us-east-1)#
#########################################

# Issue a certificate for the CloudFront alias (prod only)
resource "aws_acm_certificate" "cf" {
  count             = local.is_prod ? 1 : 0
  provider          = aws.use1         # us-east-1 provider alias
  domain_name       = var.alb_hostname # e.g., app.dentiaapp.com
  validation_method = "DNS"
  subject_alternative_names = distinct(compact(concat(
    [var.domain],
    var.marketing_subdomain != "" ? ["${var.marketing_subdomain}.${var.domain}"] : [],
    var.additional_cert_names,
    var.additional_domains
  )))

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.tags_common, {
    Name = "${local.project_env}-cf-cert"
  })
}

# DNS validation records
resource "aws_route53_record" "cf_cert_validation" {
  for_each = local.is_prod ? { for domain in local.cf_expected_domains : domain => domain } : {}

  zone_id         = data.aws_route53_zone.domains[lookup(local.host_zone_map, each.key, var.domain)].zone_id
  name            = local.cf_validation_map[each.key].resource_record_name
  type            = local.cf_validation_map[each.key].resource_record_type
  ttl             = 60
  records         = [local.cf_validation_map[each.key].resource_record_value]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cf" {
  count                   = local.is_prod ? 1 : 0
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.cf[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cf_cert_validation : r.fqdn]
}

#########################################
# WAFv2 for CloudFront (prod only)      #
#########################################

resource "aws_wafv2_web_acl" "cf" {
  provider = aws.use1
  count    = local.is_prod ? 1 : 0
  name     = "${local.project_env}-waf"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.project_env}-waf"
    sampled_requests_enabled   = true
  }

  # Common Rule Set
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    override_action {
      none {}
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.project_env}-common"
      sampled_requests_enabled   = true
    }
  }

  # Known Bad Inputs
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    override_action {
      none {}
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.project_env}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Simple IP Rate-limit (tune as needed)
  rule {
    name     = "RateLimit"
    priority = 3
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }
    action {
      block {}
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.project_env}-rate"
      sampled_requests_enabled   = true
    }
  }

  tags = merge(local.tags_common, {
    Name = "${local.project_env}-waf"
  })

  lifecycle {
    prevent_destroy = true
  }
}

#########################################
# CloudFront Policies (cache/origin)    #
#########################################

# No-cache policy for APIs / SSR HTML
resource "aws_cloudfront_cache_policy" "api_no_cache" {
  count       = local.is_prod ? 1 : 0
  name        = "${local.project_env}-api-no-cache"
  comment     = "No-caching for dynamic API/SSR"
  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = false
    enable_accept_encoding_gzip   = false

    # Forward only the headers we care about for auth / CORS
    headers_config {
      header_behavior = "none"
    }

    cookies_config {
      cookie_behavior = "none"
    }

    # APIs & SSR often depend on query strings
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

# Static long cache for Next.js assets
# Next.js automatically generates unique hashes for changed files
# So we can cache aggressively, but respect origin cache headers
resource "aws_cloudfront_cache_policy" "static_long" {
  count       = local.is_prod ? 1 : 0
  name        = "${local.project_env}-static-long"
  comment     = "Long TTL for immutable static assets (respects Cache-Control)"
  default_ttl = 31536000
  max_ttl     = 31536000
  min_ttl     = 0 # Changed from 86400 to allow shorter cache if origin says so

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    # Respect Cache-Control headers from origin
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Cache-Control"]
      }
    }
    cookies_config { cookie_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }
  }
}

# Forward ALL viewer headers/cookies/query to origin (API correctness)
resource "aws_cloudfront_origin_request_policy" "api_all" {
  count   = local.is_prod ? 1 : 0
  name    = "${local.project_env}-api-all"
  comment = "Forward all headers, cookies, and query strings to origin for API/SSR correctness"

  headers_config {
    header_behavior = "allViewer"
  }

  cookies_config {
    cookie_behavior = "all"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

#########################################
# CloudFront Distribution (prod only)   #
#########################################

resource "aws_cloudfront_distribution" "app" {
  count               = local.is_prod ? 1 : 0
  enabled             = true
  comment             = "${local.project_env} CloudFront distribution"
  default_root_object = ""
  price_class         = "PriceClass_100"
  web_acl_id          = aws_wafv2_web_acl.cf[0].arn
  aliases = distinct(compact(concat(
    [var.alb_hostname, var.domain],
    var.marketing_subdomain != "" ? ["${var.marketing_subdomain}.${var.domain}"] : [],
    var.additional_cert_names,
    var.additional_domains
  )))

  origin {
    # ALB origin
    domain_name = aws_lb.app.dns_name
    origin_id   = "alb-origin"

    # ALB is a custom origin: DO NOT use origin access control (OAC)
    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = 80
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default behavior — treat as dynamic (no caching)
  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id          = aws_cloudfront_cache_policy.api_no_cache[0].id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_all[0].id
  }

  # Next.js build assets — long TTL
  ordered_cache_behavior {
    path_pattern           = "/_next/static/*"
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id = aws_cloudfront_cache_policy.static_long[0].id
  }

  # API — explicit no-cache (redundant with default, but explicit path helps)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id          = aws_cloudfront_cache_policy.api_no_cache[0].id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_all[0].id
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cf[0].certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = merge(local.tags_common, { Name = "${local.project_env}-cf" })

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [aws_acm_certificate_validation.cf]
}

#########################################
# DNS                                   
#########################################

# PROD: app.dentiaapp.com -> CloudFront
resource "aws_route53_record" "app_alias_to_cf" {
  count           = local.is_prod ? 1 : 0
  zone_id         = data.aws_route53_zone.domains[lookup(local.host_zone_map, var.alb_hostname, var.domain)].zone_id
  name            = var.alb_hostname
  type            = "A"
  allow_overwrite = true
  alias {
    name                   = aws_cloudfront_distribution.app[0].domain_name
    zone_id                = aws_cloudfront_distribution.app[0].hosted_zone_id
    evaluate_target_health = false
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "www_alias_to_cf" {
  count           = local.is_prod ? 1 : 0
  zone_id         = data.aws_route53_zone.domains[var.domain].zone_id
  name            = "www.${var.domain}"
  type            = "A"
  allow_overwrite = true
  alias {
    name                   = aws_cloudfront_distribution.app[0].domain_name
    zone_id                = aws_cloudfront_distribution.app[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "apex_alias_to_cf" {
  count           = local.is_prod ? 1 : 0
  zone_id         = data.aws_route53_zone.domains[var.domain].zone_id
  name            = var.domain
  type            = "A"
  allow_overwrite = true
  alias {
    name                   = aws_cloudfront_distribution.app[0].domain_name
    zone_id                = aws_cloudfront_distribution.app[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# DEV: dev.dentiaapp.com -> ALB directly (cheap & simple)
resource "aws_route53_record" "dev_cname_to_alb" {
  count   = local.is_dev && var.alb_hostname != local.dev_hostname ? 1 : 0
  zone_id = data.aws_route53_zone.domains[var.domain].zone_id
  name    = local.dev_hostname
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.app.dns_name]
}
