resource "aws_sns_topic" "lambda_errors" {
  name = "${var.TagEnv}_${var.TagProject}_lambda_error_topic"
  display_name = "${var.TagEnv}_${var.TagProject}_lambda_error"
}

resource "aws_sns_topic" "codebuild_errors" {
  name = "${var.TagEnv}_${var.TagProject}_codebuild_error_topic"
  display_name = "${var.TagEnv}_${var.TagProject}_codebuild_error"
}

resource "aws_sns_topic_subscription" "lambda_error_email" {
  for_each  = toset(var.EmailsSNS)
  topic_arn = aws_sns_topic.lambda_errors.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_subscription" "codebuild_error_email" {
  for_each  = toset(var.EmailsSNS)
  topic_arn = aws_sns_topic.codebuild_errors.arn
  protocol  = "email"
  endpoint  = each.value
}

