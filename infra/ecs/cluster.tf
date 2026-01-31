resource "aws_ecs_cluster" "main" {
  name = "${local.project_id}-cluster"
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${local.project_id}-frontend"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${local.project_id}-backend"
  retention_in_days = 30
}
