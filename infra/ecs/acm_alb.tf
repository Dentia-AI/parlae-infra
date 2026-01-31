# Route53 zones for each managed domain
data "aws_route53_zone" "domains" {
  for_each     = { for domain in local.base_domains : domain => domain }
  name         = each.value
  private_zone = false
}

# ACM certificate in same region as ALB (us-east-2)
resource "aws_acm_certificate" "app" {
  domain_name               = local.primary_app_host
  subject_alternative_names = tolist(setsubtract(toset(local.certificate_hosts), toset([local.primary_app_host])))
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = merge(local.tags_common, { Name = "${local.project_id}-cert" })
}

# Create DNS validation records
resource "aws_route53_record" "app_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
      zone   = lookup(local.host_zone_map, dvo.domain_name, local.alb_hostname_domain != null ? local.alb_hostname_domain : var.domain)
    }
  }

  zone_id         = data.aws_route53_zone.domains[each.value.zone].zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

# Validate
resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for r in aws_route53_record.app_cert_validation : r.fqdn]
}

# ALB
resource "aws_lb" "app" {
  name                       = "${local.project_id}-alb"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for s in aws_subnet.public : s.id]
  tags                       = merge(local.tags_common, { Name = "${local.project_id}-alb" })
  enable_deletion_protection = local.protect_resources
}

# HTTP listener for CloudFront origin traffic
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# HTTPS listener that forwards to the frontend service by default
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.app.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}
# Route A-records to ALB for every managed host
resource "aws_route53_record" "alb_alias" {
  for_each = local.alb_host_zone_map

  zone_id         = data.aws_route53_zone.domains[each.value].zone_id
  name            = each.key
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = local.is_prod && contains(local.cloudfront_hosts, each.key) ? aws_cloudfront_distribution.app[0].domain_name : aws_lb.app.dns_name
    zone_id                = local.is_prod && contains(local.cloudfront_hosts, each.key) ? aws_cloudfront_distribution.app[0].hosted_zone_id : aws_lb.app.zone_id
    evaluate_target_health = false
  }
}
