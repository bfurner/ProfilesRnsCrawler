resource "aws_s3_bucket" "app_data_bucket" {
  bucket = "${var.bucket_name}"
  force_destroy = var.force_delete

  dynamic "lifecycle_rule" {
    for_each = var.enable_lifecycle ? [1] : []
    content {
      id      = "expire_old_files"
      enabled = true
      expiration {
        days = var.days_to_expiration
      }

      noncurrent_version_expiration {
        days = var.days_to_expiration
      }
    }
  }
}


resource "aws_s3_bucket_versioning" "s3_bucket_versioning" {
  bucket = aws_s3_bucket.app_data_bucket.id

  versioning_configuration {
    status = var.versioning
  }
}

# Allow public access to bucket if needed
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.app_data_bucket.id
  block_public_acls       = var.enable_website_hosting ? false : true
  block_public_policy     = var.enable_website_hosting ? false : true
  ignore_public_acls      = var.enable_website_hosting ? false : true
  restrict_public_buckets = var.enable_website_hosting ? false : true
}


resource "aws_s3_bucket_server_side_encryption_configuration" "state_bucket_encryption" {
  count                   = var.encryption == true ? 1 : 0 

  bucket                  = aws_s3_bucket.app_data_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


resource "aws_s3_bucket_website_configuration" "website_config" {
  count  = var.enable_website_hosting ? 1 : 0

  bucket = aws_s3_bucket.app_data_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_notification" "eventbridge" {
  count = var.enable_eventbridge_notifications ? 1 : 0

  bucket = aws_s3_bucket.app_data_bucket.id

  eventbridge = true
}