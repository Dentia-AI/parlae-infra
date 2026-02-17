locals {
  env_suffix  = var.environment == "prod" ? "" : "-${var.environment}"
  project_id  = "${var.project_name}${local.env_suffix}"
  project_env = "${var.project_name}-${var.environment}"
  is_prod     = var.environment == "prod"
  is_dev      = var.environment == "dev"
  tags_common = {
    Project     = var.project_name
    Environment = var.environment
  }
  tags = local.tags_common  # Alias for backwards compatibility
  ssm_prefix        = var.environment == "prod" ? "/${var.project_name}" : "/${var.project_name}/${var.environment}"
  protect_resources = var.protect_prod && local.is_prod

  # Database URL construction with connection pool limits
  db_base_url           = "postgresql://${var.aurora_master_username}:${urlencode(var.aurora_master_password)}@${aws_rds_cluster.aurora.endpoint}:5432/${var.aurora_db_name}?schema=public"
  frontend_database_url = "${local.db_base_url}&connection_limit=${var.frontend_db_connection_limit}"
  backend_database_url  = "${local.db_base_url}&connection_limit=${var.backend_db_connection_limit}"
  dev_hostname      = "dev.${var.domain}"

  base_domains = distinct(compact(concat([var.domain], var.additional_domains)))

  app_hosts = var.app_subdomain != "" ? distinct([
    for domain in local.base_domains : "${var.app_subdomain}.${domain}"
  ]) : []

  marketing_hosts = var.marketing_subdomain != "" ? distinct([
    for domain in local.base_domains : "${var.marketing_subdomain}.${domain}"
  ]) : []

  backend_hosts = var.api_subdomain != "" ? distinct([
    for domain in local.base_domains : "${var.api_subdomain}.${domain}"
  ]) : []

  apex_hosts         = var.include_apex_domains ? local.base_domains : []
  frontend_hostnames = distinct(concat(local.app_hosts, local.marketing_hosts, local.apex_hosts))
  backend_hostnames  = local.backend_hosts

  primary_app_host = var.alb_hostname != "" ? var.alb_hostname : (
    var.app_subdomain != "" ? "${var.app_subdomain}.${var.domain}" : var.domain
  )

  host_zone_pairs = flatten([
    for domain in local.base_domains : [
      for host in distinct(concat(
        var.app_subdomain != "" ? ["${var.app_subdomain}.${domain}"] : [],
        var.marketing_subdomain != "" ? ["${var.marketing_subdomain}.${domain}"] : [],
        var.api_subdomain != "" ? ["${var.api_subdomain}.${domain}"] : [],
        var.include_apex_domains ? [domain] : []
        )) : {
        host   = host
        domain = domain
      }
    ]
  ])

  alb_hostname_parts  = var.alb_hostname != "" ? split(".", var.alb_hostname) : []
  alb_hostname_domain = length(local.alb_hostname_parts) >= 2 ? join(".", slice(local.alb_hostname_parts, length(local.alb_hostname_parts) - 2, length(local.alb_hostname_parts))) : null
  alb_hostname_map    = var.alb_hostname != "" ? { (var.alb_hostname) = coalesce(local.alb_hostname_domain, var.domain) } : {}

  # Hub host to zone mapping (hub.parlae.ca -> parlae.ca)
  hub_host_zone_map = {
    "hub.${var.domain}" = var.domain
  }

  cognito_custom_domain_zone = var.cognito_custom_domain != "" ? try(
    [
      for domain in local.base_domains : domain
      if can(regex("${domain}$", var.cognito_custom_domain))
    ][0],
    null
  ) : null

  cognito_custom_domain_enabled = var.cognito_custom_domain != "" && local.cognito_custom_domain_zone != null

  cognito_custom_domain_map = local.cognito_custom_domain_enabled ? {
    (var.cognito_custom_domain) = local.cognito_custom_domain_zone
  } : {}

  host_zone_map = merge(
    { for pair in local.host_zone_pairs : pair.host => pair.domain },
    local.alb_hostname_map,
    local.hub_host_zone_map,
    local.cognito_custom_domain_map
  )

  alb_host_zone_map = local.cognito_custom_domain_enabled ? {
    for host, zone in local.host_zone_map : host => zone if host != var.cognito_custom_domain
  } : local.host_zone_map

  cloudfront_hosts = local.is_prod ? distinct(concat(
    [var.alb_hostname],
    local.marketing_hosts,
    local.apex_hosts
  )) : []

  # Hub hostnames (hub.*)
  hub_hosts = [
    "hub.${var.domain}",
  ]

  certificate_hosts = distinct(concat(
    [local.primary_app_host],
    local.app_hosts,
    local.marketing_hosts,
    local.backend_hosts,
    local.apex_hosts,
    local.hub_hosts,
    var.additional_cert_names,
    local.cognito_custom_domain_enabled ? [var.cognito_custom_domain] : []
  ))
}
