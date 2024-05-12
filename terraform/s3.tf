variable "S3Name" {
  type        = string
  default     = "project"
}

resource "aws_s3_bucket" "s3_bucket_art" {
  bucket = "${var.TagEnv}-${var.S3Name}-dbt-art"

}

resource "aws_s3_bucket" "s3_bucket_public" {
  bucket = "${var.TagEnv}-${var.S3Name}-dbt-public"
}

# public

resource "aws_s3_bucket_website_configuration" "website_bucket" {
  bucket = aws_s3_bucket.s3_bucket_public.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "access_block" {
  bucket = aws_s3_bucket.s3_bucket_public.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  bucket = aws_s3_bucket.s3_bucket_public.id
  policy = data.aws_iam_policy_document.allow_access_from_another_account.json
}

data "aws_iam_policy_document" "allow_access_from_another_account" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_bucket.s3_bucket_public.arn,
      "${aws_s3_bucket.s3_bucket_public.arn}/*",
    ]
  }
}

