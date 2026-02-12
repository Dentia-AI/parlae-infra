# Target groups (placeholders until ECS services attach)
resource "aws_lb_target_group" "frontend" {
  name        = "${local.project_id}-frontend-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # Enable sticky sessions for OAuth flows (nonce, PKCE, state)
  # This ensures OAuth callbacks return to the same container that initiated the flow
  stickiness {
    enabled         = true
    type            = "lb_cookie"
    cookie_duration = 86400 # 24 hours
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "${local.project_id}-backend-tg"
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# HTTPS listener rules
locals {
  frontend_host_chunks = {
    for idx, domain in local.base_domains : idx => distinct(compact([
      var.app_subdomain != "" ? "${var.app_subdomain}.${domain}" : null,
      var.marketing_subdomain != "" ? "${var.marketing_subdomain}.${domain}" : null,
      var.include_apex_domains ? domain : null
    ]))
  }
}

resource "aws_lb_listener_rule" "backend_host" {
  count        = length(local.backend_hostnames) > 0 ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 5
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
  condition {
    host_header { values = local.backend_hostnames }
  }
}

# Backend API routes - MUST come before frontend catch-all
resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 8
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
  condition {
    path_pattern { values = ["/api/*"] }
  }
}

# Frontend routes - catch all remaining traffic
resource "aws_lb_listener_rule" "frontend_root" {
  for_each     = local.frontend_host_chunks
  listener_arn = aws_lb_listener.https.arn
  priority     = 10 + tonumber(each.key)
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
  condition {
    host_header { values = each.value }
  }
  condition {
    path_pattern { values = ["/*"] }
  }
}
