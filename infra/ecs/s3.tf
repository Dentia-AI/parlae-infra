resource "aws_s3_bucket" "uploads" {
  bucket        = "${local.project_id}-uploads-${var.region}"
  force_destroy = false
  tags          = merge(local.tags_common, { Name = "${local.project_id}-uploads" })
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "s3_bucket_name" { value = aws_s3_bucket.uploads.bucket }
