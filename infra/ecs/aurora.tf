##########################
# Aurora PostgreSQL v2   #
##########################

# Subnet group
resource "aws_db_subnet_group" "aurora" {
  name       = "${local.project_id}-aurora-subnet-group"
  subnet_ids = [for s in aws_subnet.private : s.id]
  tags       = merge(local.tags_common, { Name = "${local.project_id}-aurora-subnet-group" })
}

# Cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${local.project_id}-aurora-cluster"
  engine             = "aurora-postgresql"
  engine_version     = "15.12"
  engine_mode        = "provisioned"

  database_name             = "dentia"
  master_username           = "dentia_admin"
  master_password           = "S7#tY4^zN9_Rq2+xS8!nV9d"
  db_subnet_group_name      = aws_db_subnet_group.aurora.name
  vpc_security_group_ids    = [aws_security_group.db.id]
  backup_retention_period   = 3
  storage_encrypted         = true
  skip_final_snapshot       = !local.protect_resources
  final_snapshot_identifier = local.protect_resources ? "${local.project_id}-aurora-final" : null

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  tags = merge(local.tags_common, { Name = "${local.project_id}-aurora-cluster" })

  deletion_protection = local.protect_resources
}

# Instance (required for v2)
resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier          = "${local.project_id}-aurora-instance"
  cluster_identifier  = aws_rds_cluster.aurora.id
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.aurora.engine
  engine_version      = aws_rds_cluster.aurora.engine_version
  publicly_accessible = false
}

output "aurora_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "aurora_cluster_id" {
  value = aws_rds_cluster.aurora.id
}
