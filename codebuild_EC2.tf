resource "aws_iam_role" "codebuild_role" {
  name = "${var.TagEnv}_${var.TagProject}_codebuild_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_access_policy" {
  name   = "${var.TagEnv}_${var.TagProject}_CodeBuildAccess"
  role   = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:*",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeVpcs",
          "ec2:CreateNetworkInterfacePermission"
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = "secretsmanager:GetSecretValue",
        Effect = "Allow",
        Resource = aws_secretsmanager_secret.secretsmanager.arn
      }
    ]
  })
}

resource "aws_iam_policy" "codebuild_managed_policy" {
  name   = "${var.TagEnv}_${var.TagProject}_codebuild_access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeVpcs"
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:CreateNetworkInterfacePermission"
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "logs:DescribeLogGroups",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "cloudwatch_events_codebuild_role" {
  name = "${var.TagEnv}_${var.TagProject}_CloudWatchEventsCodeBuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "cloudwatch_build_access_policy" {
  name   = "${var.TagEnv}_${var.TagProject}_CloudWatchDbtBuild"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "codebuild:StartBuild",
        Resource = aws_codebuild_project.dbt_codebuild_project.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy_to_cloudwatch_role" {
  role       = aws_iam_role.cloudwatch_events_codebuild_role.id
  policy_arn = aws_iam_policy.cloudwatch_build_access_policy.arn
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = aws_secretsmanager_secret.secretsmanager.id
}

resource "aws_codebuild_source_credential" "github" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = jsondecode(data.aws_secretsmanager_secret_version.github_token.secret_string)["token_github"]
}

resource "aws_codebuild_project" "dbt_codebuild_project" {
  name          = "${var.TagEnv}_${var.TagProject}_codebuild_project"
  description   = "Project to build code from GitHub"
  build_timeout = "15"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "S3"
    location = aws_s3_bucket.s3_bucket_art.bucket
    name = "${var.TagEnv}_${var.TagProject}_codebuild_log"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "secret_manager"
      value = aws_secretsmanager_secret.secretsmanager.name
    }
    environment_variable {
      name  = "s3_public"
      value = aws_s3_bucket.s3_bucket_public.bucket
    }

  }

  logs_config {
    cloudwatch_logs {
      group_name = "aws/codebuild/${var.TagEnv}_${var.TagProject}_codebuild_project"
      status = "ENABLED"
      stream_name = ""
    }
  }
  source {
    type            = "GITHUB"
    location        = var.github_repositorio
    git_clone_depth = 1
    buildspec       = "config/buildspec.yml"
  }
  depends_on = [aws_secretsmanager_secret_version.secret_version]
}
