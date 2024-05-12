variable "build_environment" {
  type        = string
  description = "qual tipo de computacao sera usada no codebuild? lambda ou ec2."

  validation {
    condition     = var.build_environment == "lambda" || var.build_environment == "ec2"
    error_message = "Invalid build environment type. Valid options are 'lambda' or 'ec2'."
  }
}

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
  depends_on = [aws_secretsmanager_secret_version.secret_version]
}

resource "aws_codebuild_source_credential" "github" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = jsondecode(data.aws_secretsmanager_secret_version.github_token.secret_string)["token_github"]
  depends_on = [aws_secretsmanager_secret_version.secret_version]
}

resource "aws_codebuild_project" "dbt_codebuild_project" {
  name          = "${var.TagEnv}_${var.TagProject}_codebuild_project"
  description   = "Project to build code from GitHub"
  build_timeout = "60"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type     = "S3"
    location = aws_s3_bucket.s3_bucket_art.bucket
    name     = "${var.TagEnv}_${var.TagProject}_codebuild_log"
  }

  environment {
    compute_type = var.build_environment == "lambda" ? "BUILD_LAMBDA_1GB" : "BUILD_GENERAL1_SMALL"
    image        = var.build_environment == "lambda" ? "aws/codebuild/amazonlinux-x86_64-lambda-standard:python3.11" : "aws/codebuild/standard:7.0"
    type         = var.build_environment == "lambda" ? "LINUX_LAMBDA_CONTAINER" : "LINUX_CONTAINER"

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
      group_name  = "${var.TagEnv}_${var.TagProject}_codebuild_project"
      status      = "ENABLED"
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repositorio
    git_clone_depth = 1
    buildspec       = "config/buildspec.yml"
  }

  depends_on = [aws_iam_access_key.access_key]

}

resource "aws_iam_policy" "codebuild_sns_publish" {
  name   = "${var.TagEnv}_${var.TagProject}_codebuild_sns_publish"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sns:Publish",
        Resource = aws_sns_topic.codebuild_errors.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_sns_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_sns_publish.arn
}

resource "aws_cloudwatch_event_rule" "codebuild_failure_rule" {
  name        = "${var.TagEnv}_${var.TagProject}_codebuild_failure_rule"
  description = "Monitor CodeBuild project failures."
  event_pattern = jsonencode({
    source = ["aws.codebuild"],
    detail-type = ["CodeBuild Build State Change"],
    detail = {
      "build-status" = ["TIMED_OUT", "FAILED", "FAULT", "CLIENT_ERROR"],
      "project-name" = [aws_codebuild_project.dbt_codebuild_project.name]
    }

  })
}

resource "aws_cloudwatch_event_target" "failure_notification_target" {
  rule      = aws_cloudwatch_event_rule.codebuild_failure_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.codebuild_errors.arn

  input_transformer {
    input_paths = {
      "version"  = "$.version",
      "id"  = "$.id",
      "detailtype"  = "$.detail-type",
      "source"  = "$.source",
      "account"  = "$.account",
      "time"  = "$.time",
      "region"  = "$.region",
      "projectname"  = "$.detail.project-name",
      "buildid"  = "$.detail.build-id",
      "buildstatus"  = "$.detail.build-status",
      "currentphase"  = "$.detail.current-phase",
      "currentphasecontext"  = "$.detail.current-phase-context",
      "versionbuild"  = "$.detail.version",
      "additionalinformation"  = "$.detail"
    }

    input_template =  <<INPUT_TEMPLATE_EOF
    {
        "version" : <version>,
        "id" : <id>,
        "detailtype" : <detailtype>,
        "source" : <source>,
        "account" : <account>,
        "time" : <time>,
        "region" : <region>,
        "projectname" : <projectname>,
        "buildid" : <buildid>,
        "buildstatus" : <buildstatus>,
        "currentphase" : <currentphase>,
        "currentphasecontext" : <currentphasecontext>,
        "additionalinformation" : <additionalinformation>
    }
    INPUT_TEMPLATE_EOF


  }
}

resource "aws_sns_topic_policy" "sns_topic_policy" {
  arn    = aws_sns_topic.codebuild_errors.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    actions   = ["SNS:Publish"]
    effect    = "Allow"
    resources = [aws_sns_topic.codebuild_errors.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

