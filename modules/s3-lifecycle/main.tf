# Dedicated S3 bucket for retaining environment logs with a cost-aware lifecycle.

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.project}-${var.environment}-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project}-${var.environment}-logs-${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  # Enforce secure defaults: no public ACLs/policies and no public bucket access
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log-retention-lifecycle"
    status = "Enabled"

    # Apply rule to all objects in this bucket
    filter {}

    # Move older logs to cheaper storage before final deletion
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  # Protect data at rest with AES256 encryption
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
