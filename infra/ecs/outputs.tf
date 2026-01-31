output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_ids" { value = [for s in aws_subnet.public : s.id] }
output "private_subnet_ids" { value = [for s in aws_subnet.private : s.id] }
output "alb_sg_id" { value = aws_security_group.alb.id }
output "ecs_sg_id" { value = aws_security_group.ecs.id }
output "db_sg_id" { value = aws_security_group.db.id }
output "alb_dns_name" { value = aws_lb.app.dns_name }
output "alb_hostname" { value = var.alb_hostname }
output "certificate_arn" { value = aws_acm_certificate_validation.app.certificate_arn }
output "ecs_cluster_name" { value = aws_ecs_cluster.main.name }
output "ecs_cluster_id" { value = aws_ecs_cluster.main.id }
output "frontend_log_group" { value = aws_cloudwatch_log_group.frontend.name }
output "backend_log_group" { value = aws_cloudwatch_log_group.backend.name }
output "alerts_topic_arn" { value = aws_sns_topic.alerts.arn }
output "alb_arn" { value = aws_lb.app.arn }
output "bastion_instance_id" { value = aws_instance.bastion.id }
output "bastion_security_group_id" { value = aws_security_group.bastion.id }
output "route53_zone_ids" {
  value = { for domain, zone in data.aws_route53_zone.domains : domain => zone.zone_id }
}

output "route53_zone_id" {
  description = "Route53 zone id for the primary domain."
  value       = data.aws_route53_zone.domains[var.domain].zone_id
}
output "region" { value = var.region }
output "project_name" { value = var.project_name }

# Monitoring & Auto-Scaling Outputs
output "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = aws_sns_topic.alerts.arn
}

output "frontend_max_tasks" {
  description = "Maximum number of frontend tasks configured"
  value       = var.frontend_max_tasks
}

output "backend_max_tasks" {
  description = "Maximum number of backend tasks configured"
  value       = var.backend_max_tasks
}

output "aurora_max_capacity" {
  description = "Maximum Aurora capacity in ACUs"
  value       = var.aurora_max_capacity
}

output "alert_emails" {
  description = "Email addresses receiving alerts"
  value       = var.alert_emails
  sensitive   = true
}

output "slack_notifications_enabled" {
  description = "Whether Slack notifications are enabled"
  value       = var.slack_webhook_url != "" ? "Yes" : "No"
  sensitive   = true
}
