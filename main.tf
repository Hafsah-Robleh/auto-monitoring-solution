 provider "aws" {
  region = "us-east-2"
}

# ---------------- EC2 ----------------
resource "aws_instance" "app" {
  ami           = "ami-0abcdef1234567890" # replace with real AMI
  instance_type = "t2.micro"

  tags = {
    Name = "api-server"
  }
}

# ---------------- SNS ----------------
resource "aws_sns_topic" "alerts" {
  name = "sumo-alerts"
}

# ---------------- IAM ROLE ----------------
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# ---------------- IAM POLICY ----------------
resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["ec2:RebootInstances"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# ---------------- LAMBDA ----------------
resource "aws_lambda_function" "auto_recover" {
  function_name = "SumoTriggeredRecovery"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = "lambda_function.zip"

  environment {
    variables = {
      INSTANCE_ID   = aws_instance.app.id
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

# ---------------- SNS → LAMBDA ----------------
resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.auto_recover.arn
}

# ---------------- ALLOW SNS TO TRIGGER LAMBDA ----------------
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowSNSToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_recover.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
} 