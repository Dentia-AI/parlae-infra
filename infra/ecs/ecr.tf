resource "aws_ecr_repository" "frontend" {
  name = "${local.project_id}-frontend"
  image_scanning_configuration { scan_on_push = true }
  tags = merge(local.tags_common, { Name = "${local.project_id}-frontend" })
}

resource "aws_ecr_repository" "backend" {
  name = "${local.project_id}-backend"
  image_scanning_configuration { scan_on_push = true }
  tags = merge(local.tags_common, { Name = "${local.project_id}-backend" })
}
