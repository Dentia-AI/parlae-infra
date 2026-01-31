locals {
  aurora_capacity_alarm_threshold = var.aurora_max_capacity * var.aurora_capacity_utilization_threshold
  frontend_max_tasks_threshold    = var.frontend_max_tasks * var.ecs_max_tasks_threshold
  backend_max_tasks_threshold     = var.backend_max_tasks * var.ecs_max_tasks_threshold
}

###################
# SNS Topics
###################

resource "aws_sns_topic" "alerts" {
  name = "${local.project_id}-alerts"
  
  tags = {
    Name        = "${local.project_id}-alerts"
    Environment = var.environment
  }
}

# Email Subscriptions
resource "aws_sns_topic_subscription" "alert_email_subscribers" {
  for_each = { for email in var.alert_emails : email => email }

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# Slack Webhook Integration (via Lambda)
resource "aws_lambda_function" "slack_notification" {
  count = var.slack_webhook_url != "" ? 1 : 0

  filename      = "${path.module}/lambda/slack_notification.zip"
  function_name = "${local.project_id}-slack-notification"
  role          = aws_iam_role.lambda_slack[0].arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 10

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

resource "aws_iam_role" "lambda_slack" {
  count = var.slack_webhook_url != "" ? 1 : 0
  name  = "${local.project_id}-lambda-slack-notification"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_slack_basic" {
  count      = var.slack_webhook_url != "" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_slack[0].name
}

resource "aws_sns_topic_subscription" "slack_lambda" {
  count     = var.slack_webhook_url != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notification[0].arn
}

resource "aws_lambda_permission" "sns_invoke_slack" {
  count         = var.slack_webhook_url != "" ? 1 : 0
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notification[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

resource "aws_cloudwatch_metric_alarm" "frontend_service_unhealthy" {
  alarm_name          = "${local.project_id}-frontend-running"
  alarm_description   = "Alarm when the frontend ECS service has no running tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  threshold           = 1
  treat_missing_data  = "breaching"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.frontend.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "backend_service_unhealthy" {
  alarm_name          = "${local.project_id}-backend-running"
  alarm_description   = "Alarm when the backend ECS service has no running tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  threshold           = 1
  treat_missing_data  = "breaching"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "aurora_capacity_high" {
  alarm_name          = "${local.project_id}-aurora-capacity-high"
  alarm_description   = "CRITICAL: Aurora Serverless capacity approaching configured maximum (${var.aurora_max_capacity} ACUs)"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = local.aurora_capacity_alarm_threshold
  treat_missing_data  = "notBreaching"
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Maximum"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

###################
# ECS Scaling Limit Alarms
###################

resource "aws_cloudwatch_metric_alarm" "frontend_max_tasks_approaching" {
  alarm_name          = "${local.project_id}-frontend-max-tasks-approaching"
  alarm_description   = "WARNING: Frontend approaching max task limit (${var.frontend_max_tasks} tasks). Consider increasing max capacity."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = local.frontend_max_tasks_threshold
  treat_missing_data  = "notBreaching"
  metric_name         = "DesiredTaskCount"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.frontend.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "backend_max_tasks_approaching" {
  alarm_name          = "${local.project_id}-backend-max-tasks-approaching"
  alarm_description   = "WARNING: Backend approaching max task limit (${var.backend_max_tasks} tasks). Consider increasing max capacity."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = local.backend_max_tasks_threshold
  treat_missing_data  = "notBreaching"
  metric_name         = "DesiredTaskCount"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

###################
# High CPU/Memory Alarms
###################

resource "aws_cloudwatch_metric_alarm" "frontend_cpu_high" {
  alarm_name          = "${local.project_id}-frontend-cpu-high"
  alarm_description   = "WARNING: Frontend CPU utilization is high (>80%)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 80
  treat_missing_data  = "notBreaching"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.frontend.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name          = "${local.project_id}-backend-cpu-high"
  alarm_description   = "WARNING: Backend CPU utilization is high (>80%)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 80
  treat_missing_data  = "notBreaching"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "frontend_memory_high" {
  alarm_name          = "${local.project_id}-frontend-memory-high"
  alarm_description   = "WARNING: Frontend memory utilization is high (>85%)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 85
  treat_missing_data  = "notBreaching"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.frontend.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "backend_memory_high" {
  alarm_name          = "${local.project_id}-backend-memory-high"
  alarm_description   = "WARNING: Backend memory utilization is high (>85%)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 85
  treat_missing_data  = "notBreaching"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

###################
# ALB Health & Performance Alarms
###################

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets_frontend" {
  alarm_name          = "${local.project_id}-alb-unhealthy-targets-frontend"
  alarm_description   = "CRITICAL: Frontend has unhealthy targets in ALB"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 0
  treat_missing_data  = "notBreaching"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.frontend.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets_backend" {
  alarm_name          = "${local.project_id}-alb-unhealthy-targets-backend"
  alarm_description   = "CRITICAL: Backend has unhealthy targets in ALB"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 0
  treat_missing_data  = "notBreaching"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors_high" {
  alarm_name          = "${local.project_id}-alb-5xx-errors-high"
  alarm_description   = "CRITICAL: ALB is returning high rate of 5xx errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 10
  treat_missing_data  = "notBreaching"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time_high" {
  alarm_name          = "${local.project_id}-alb-target-response-time-high"
  alarm_description   = "WARNING: ALB target response time is high (>2s)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 2
  treat_missing_data  = "notBreaching"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

###################
# Database Connection & Performance Alarms
###################

resource "aws_cloudwatch_metric_alarm" "aurora_database_connections_high" {
  alarm_name          = "${local.project_id}-aurora-connections-high"
  alarm_description   = "WARNING: Aurora database connections are high (>80% of max)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  # Aurora Serverless typically supports ~16000 connections per ACU
  # This is a conservative threshold at 500 connections
  threshold          = 500
  treat_missing_data = "notBreaching"
  metric_name        = "DatabaseConnections"
  namespace          = "AWS/RDS"
  period             = 60
  statistic          = "Maximum"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "aurora_cpu_high" {
  alarm_name          = "${local.project_id}-aurora-cpu-high"
  alarm_description   = "WARNING: Aurora CPU utilization is high (>80%)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 80
  treat_missing_data  = "notBreaching"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "aurora_max_capacity_reached" {
  alarm_name          = "${local.project_id}-aurora-max-capacity-reached"
  alarm_description   = "CRITICAL: Aurora has reached maximum configured capacity (${var.aurora_max_capacity} ACUs). Database cannot scale further!"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = var.aurora_max_capacity
  treat_missing_data  = "notBreaching"
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Maximum"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "aurora_free_storage_low" {
  alarm_name          = "${local.project_id}-aurora-free-storage-low"
  alarm_description   = "WARNING: Aurora free storage space is low (<10GB)"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  threshold           = 10000000000 # 10GB in bytes
  treat_missing_data  = "notBreaching"
  metric_name         = "FreeLocalStorage"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

###################
# Request Rate Alarms
###################

resource "aws_cloudwatch_metric_alarm" "alb_request_surge" {
  alarm_name          = "${local.project_id}-alb-request-surge"
  alarm_description   = "INFO: Experiencing high request volume. Auto-scaling should handle this."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 10000
  treat_missing_data  = "notBreaching"
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
