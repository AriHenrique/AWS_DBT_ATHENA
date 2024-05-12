resource "aws_iam_role" "lambda_role" {
  name = "${var.TagEnv}_${var.TagProject}_lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "codebuild:StartBuild",
          "sns:Publish"
        ],
        Resource = [aws_codebuild_project.dbt_codebuild_project.arn, aws_sns_topic.lambda_errors.arn],
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_lambda_function" "dbt_init" {
  function_name = "${var.TagEnv}_${var.TagProject}_${var.LambdaName}"
  handler          = "dbt_init.main"
  runtime          = "python3.8"
  role             = aws_iam_role.lambda_role.arn
  timeout = 10
  memory_size = 128
  tags = {
    Project = var.TagProject,
    Environment = var.TagEnv
  }
  environment {
    variables = {
      code_build_name = aws_codebuild_project.dbt_codebuild_project.name,
      sns_topic_arn = aws_sns_topic.lambda_errors.arn
    }
  }

  filename         = data.archive_file.lambda_output.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda_output.output_path)
  depends_on = [aws_iam_access_key.access_key]
}

data "archive_file" "lambda_output" {
  type        = "zip"
  source_file = format("%s/dbt_init.py", path.module)
  output_path = format("%s/dbt_init.zip", path.module)
}

output "sns_topic_arn" {
  value = aws_sns_topic.lambda_errors.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.dbt_init.function_name
}
