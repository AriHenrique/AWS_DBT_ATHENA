resource "aws_iam_group" "group" {
  name = "${var.TagEnv}_${var.TagProject}_${var.GroupName}"
}

resource "aws_iam_group_policy_attachment" "athena_full_access" {
  group      = aws_iam_group.group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}

resource "aws_iam_group_policy_attachment" "s3_full_access" {
  group      = aws_iam_group.group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_group_policy_attachment" "stepfunctions_full_access" {
  group      = aws_iam_group.group.name
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
}

resource "aws_iam_user" "user" {
  name  = "${var.TagEnv}_${var.TagProject}_${var.UserName}"
  force_destroy = true
  depends_on = [aws_s3_bucket.s3_bucket_public,aws_s3_bucket.s3_bucket_art ]
}

resource "aws_iam_group_membership" "user_membership" {
  name = "${var.TagEnv}_${var.TagProject}_${var.GroupName}_membership"
  users = [
    aws_iam_user.user.name,
  ]
  group = aws_iam_group.group.name
}

resource "aws_iam_access_key" "access_key" {
  user = aws_iam_user.user.name
  depends_on = [aws_iam_user.user]
}
