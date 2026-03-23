 provider "aws" {
  region = "us-east-2"
}

# ---------------- EC2 ----------------
resource "aws_instance" "app" {
  ami           = "ami-0b0b78dcacbab728f"   
  instance_type = "t2.micro"

  tags = {
    Name = "existing-ec2"
  }
}

# ---------------- SNS ----------------
resource "aws_sns_topic" "alerts" {
  name = "monitoring-sns"
}

# ---------------- IAM ROLE (for Lambda) ----------------
resource "aws_iam_role" "lambda_role" {
  name = "lambda-existing-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Least privilege policy
resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id

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
        Action = ["sns:Publish"],
        Resource = "arn:aws:sns:us-east-2:265145884108:monitoring-sns"
      },
      {
        Effect = "Allow",
        Action = ["logs:*"],
        Resource = "*"
      }
    ]
  })
}

# ---------------- Lambda ----------------
resource "aws_lambda_function" "app_lambda" {
  function_name = "api-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  filename = "lambda.zip"

  environment {
    variables = {
      INSTANCE_ID   = "i-0510c100a8706cd17"
      SNS_TOPIC_ARN = "arn:aws:sns:us-east-2:265145884108:monitoring-sns"
    }
  }
}