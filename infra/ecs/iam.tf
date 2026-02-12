# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Execution role (pulls from ECR, writes logs, reads secrets)
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.project_id}-ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust.json
}

data "aws_iam_policy_document" "ecs_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_exec_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Extra inline permissions (optional: SSM/Secrets get)
resource "aws_iam_role_policy" "ecs_exec_extra" {
  name = "${local.project_id}-ecs-exec-extra"
  role = aws_iam_role.ecs_task_execution.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "secretsmanager:GetSecretValue"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Task role (your app’s runtime AWS access)
resource "aws_iam_role" "ecs_task" {
  name               = "${local.project_id}-ecsTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust.json
}

# (Attach least-privilege app policies later as needed)
