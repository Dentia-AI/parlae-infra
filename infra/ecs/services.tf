#############################
# ECS Task Definitions      #
#############################

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${local.project_id}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name         = "frontend"
      image        = "${aws_ecr_repository.frontend.repository_url}:latest"
      portMappings = [{ containerPort = 3000, protocol = "tcp" }]
      essential    = true
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.frontend.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "frontend"
        }
      }
      environment = [
        { name = "NODE_ENV", value = local.is_prod ? "production" : "development" },
        { name = "APP_HOSTS", value = join(",", local.app_hosts) },
        {
          name  = "MARKETING_HOSTS",
          value = join(",", distinct(concat(local.marketing_hosts, var.include_apex_domains ? local.apex_hosts : [])))
        },
        { name = "TRUST_PROXY", value = "1" },
        { name = "COOKIE_DOMAIN", value = ".${var.domain}" },
        {
          name  = "DISCOURSE_SSO_ALLOWED_RETURN_URLS",
          value = join(",", [for host in local.hub_hosts : "https://${host}/session/sso_login"])
        }
      ]
      secrets = [
        { name = "NEXTAUTH_URL", valueFrom = "${local.ssm_prefix}/frontend/NEXTAUTH_URL" },
        { name = "NEXTAUTH_SECRET", valueFrom = "${local.ssm_prefix}/frontend/NEXTAUTH_SECRET" },
        { name = "COGNITO_CLIENT_ID", valueFrom = "${local.ssm_prefix}/frontend/COGNITO_CLIENT_ID" },
        { name = "COGNITO_CLIENT_SECRET", valueFrom = "${local.ssm_prefix}/frontend/COGNITO_CLIENT_SECRET" },
        { name = "COGNITO_ISSUER", valueFrom = "${local.ssm_prefix}/frontend/COGNITO_ISSUER" },
        { name = "COGNITO_DOMAIN", valueFrom = "${local.ssm_prefix}/frontend/COGNITO_DOMAIN" },
        { name = "DATABASE_URL", valueFrom = "${local.ssm_prefix}/frontend/DATABASE_URL" },
        { name = "AWS_REGION", valueFrom = "${local.ssm_prefix}/shared/AWS_REGION" },
        { name = "S3_BUCKET", valueFrom = "${local.ssm_prefix}/shared/S3_BUCKET" },
        { name = "BACKEND_API_URL", valueFrom = "${local.ssm_prefix}/frontend/BACKEND_API_URL" },
        { name = "DISCOURSE_SSO_SECRET", valueFrom = "${local.ssm_prefix}/frontend/DISCOURSE_SSO_SECRET" },
        { name = "STRIPE_PUBLISHABLE_KEY", valueFrom = "${local.ssm_prefix}/shared/STRIPE_PUBLISHABLE_KEY" },
        { name = "STRIPE_SECRET_KEY", valueFrom = "${local.ssm_prefix}/shared/STRIPE_SECRET_KEY" },
        { name = "STRIPE_WEBHOOK_SECRET", valueFrom = "${local.ssm_prefix}/shared/STRIPE_WEBHOOK_SECRET" },
        # GoHighLevel
        { name = "GHL_API_KEY", valueFrom = "${local.ssm_prefix}/frontend/GHL_API_KEY" },
        { name = "GHL_LOCATION_ID", valueFrom = "${local.ssm_prefix}/frontend/GHL_LOCATION_ID" },
        { name = "NEXT_PUBLIC_GHL_WIDGET_ID", valueFrom = "${local.ssm_prefix}/frontend/NEXT_PUBLIC_GHL_WIDGET_ID" },
        { name = "NEXT_PUBLIC_GHL_LOCATION_ID", valueFrom = "${local.ssm_prefix}/frontend/NEXT_PUBLIC_GHL_LOCATION_ID" },
        { name = "NEXT_PUBLIC_GHL_CALENDAR_ID", valueFrom = "${local.ssm_prefix}/frontend/NEXT_PUBLIC_GHL_CALENDAR_ID" }
      ]
    }
  ])
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.project_id}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name         = "backend"
      image        = "${aws_ecr_repository.backend.repository_url}:latest"
      portMappings = [{ containerPort = 4000, protocol = "tcp" }]
      essential    = true
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.backend.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "backend"
        }
      }
      environment = [
        { name = "NODE_ENV", value = local.is_prod ? "production" : "development" },
        { name = "PORT", value = "4000" }
      ]
      secrets = [
        { name = "DATABASE_URL", valueFrom = "${local.ssm_prefix}/backend/DATABASE_URL" },
        { name = "AWS_REGION", valueFrom = "${local.ssm_prefix}/shared/AWS_REGION" },
        { name = "S3_BUCKET", valueFrom = "${local.ssm_prefix}/shared/S3_BUCKET" },
        { name = "COGNITO_USER_POOL_ID", valueFrom = "${local.ssm_prefix}/shared/COGNITO_USER_POOL_ID" },
        { name = "COGNITO_CLIENT_ID", valueFrom = "${local.ssm_prefix}/shared/COGNITO_CLIENT_ID" },
        { name = "COGNITO_ISSUER", valueFrom = "${local.ssm_prefix}/shared/COGNITO_ISSUER" },
        { name = "STRIPE_SECRET_KEY", valueFrom = "${local.ssm_prefix}/shared/STRIPE_SECRET_KEY" },
        { name = "STRIPE_WEBHOOK_SECRET", valueFrom = "${local.ssm_prefix}/shared/STRIPE_WEBHOOK_SECRET" }
      ]
    }
  ])
}

#############################
# ECS Services (behind ALB) #
#############################

resource "aws_ecs_service" "frontend" {
  name                   = "${local.project_id}-frontend"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.frontend.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = [for s in aws_subnet.public : s.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 3000
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
  depends_on = [aws_lb_listener_rule.frontend_root]
}

resource "aws_ecs_service" "backend" {
  name                   = "${local.project_id}-backend"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.backend.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = [for s in aws_subnet.public : s.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 4000
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
  depends_on = [aws_lb_listener_rule.backend_api]
}

################################
# App AutoScaling (CPU target) #
################################

# FRONTEND
resource "aws_appautoscaling_target" "frontend" {
  max_capacity       = var.frontend_max_tasks
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.frontend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "frontend_cpu" {
  name               = "${local.project_id}-frontend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 65
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "frontend_memory" {
  name               = "${local.project_id}-frontend-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

# ALB Request Count Based Scaling for Frontend
resource "aws_appautoscaling_policy" "frontend_alb_requests" {
  name               = "${local.project_id}-frontend-alb-requests-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.frontend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.frontend.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.alb_request_count_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 30
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.app.arn_suffix}/${aws_lb_target_group.frontend.arn_suffix}"
    }
  }
}

# BACKEND
resource "aws_appautoscaling_target" "backend" {
  max_capacity       = var.backend_max_tasks
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "backend_cpu" {
  name               = "${local.project_id}-backend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 65
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "backend_memory" {
  name               = "${local.project_id}-backend-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

# ALB Request Count Based Scaling for Backend
resource "aws_appautoscaling_policy" "backend_alb_requests" {
  name               = "${local.project_id}-backend-alb-requests-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.backend.resource_id
  scalable_dimension = aws_appautoscaling_target.backend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.backend.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.alb_request_count_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 30
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.app.arn_suffix}/${aws_lb_target_group.backend.arn_suffix}"
    }
  }
}
