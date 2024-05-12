resource "aws_secretsmanager_secret" "secretsmanager" {
  name = "${var.TagEnv}_${var.TagProject}_secret_${md5(timestamp())}"
}

resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id     = aws_secretsmanager_secret.secretsmanager.id
  secret_string = jsonencode({
    access_id    = aws_iam_access_key.access_key.id
    access_key   = aws_iam_access_key.access_key.secret
    token_github = var.github_oauth_token
  })
  depends_on = [aws_iam_access_key.access_key]

}