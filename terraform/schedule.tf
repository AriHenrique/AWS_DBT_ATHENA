resource "aws_iam_role" "schedule_role" {
  name = "${var.TagEnv}_${var.TagProject}_cron_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["scheduler.amazonaws.com"]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "scheduler_policy_attachment" {
  policy_arn = aws_iam_policy.policy_scheduler.arn
  role       = aws_iam_role.schedule_role.name
}

resource "aws_iam_policy" "policy_scheduler" {
  name = "${var.TagEnv}_${var.TagProject}_cron_policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action   = [
          "lambda:InvokeFunction",
          "lambda:ListFunctions"
        ]
        Resource = [aws_lambda_function.dbt_init.arn]
      }
    ]
  })
}

resource "aws_scheduler_schedule_group" "schedule_group" {
  name = "diario"
}

resource "aws_scheduler_schedule" "schedule_lambda" {
  name                         = "init_dbt"
  group_name                   = aws_scheduler_schedule_group.schedule_group.name
  description                  = "Todos os dias as ${var.HourSchedule} Hours e ${var.MinuteSchedule} Minutos"
  state                        = "DISABLED"
  schedule_expression_timezone = var.TimeZone
  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(${var.MinuteSchedule} ${var.HourSchedule} * * ? *)"

  target {
    arn      = aws_lambda_function.dbt_init.arn
    role_arn = aws_iam_role.schedule_role.arn
  }
}