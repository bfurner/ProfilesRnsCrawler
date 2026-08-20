provider "aws" {
  region = "us-east-1"

}

resource "aws_iam_role" "lambda_exec_role" {
  name = "rdf-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "step_function_role" {
  name = "rdf-step-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_s3_write" {
  name = "rdf-lambda-s3-write"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject"]
      Resource = "${module.s3_bucket.bucket_arn}/rdf/*"
    }]
  })
}

resource "aws_iam_role_policy" "step_function_invoke_lambda" {
  name = "invoke-lambdas"
  role = aws_iam_role.step_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "lambda:InvokeFunction"
      Resource = [
        module.lambda_crawl.lambda_arn,
        module.lambda_download.lambda_arn,
        module.lambda_load.lambda_arn
      ]
    }]
  })
}

resource "aws_iam_role" "eventbridge_sfn_role" {
  name = "rdf-eventbridge-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_start_execution" {
  name = "start-sfn-execution"
  role = aws_iam_role.eventbridge_sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.rdf_pipeline.arn
    }]
  })
}

module "s3_bucket" {
  source       = "./modules/s3"
  bucket_name  = var.bucket_name
  force_delete = true
  versioning   = "Enabled"
}

module "lambda_crawl" {
  source                      = "./modules/lambda"
  lambda_function_name        = "lambda-crawl"
  lambda_function_source_dir  = "${path.module}/../functions/crawl"
  lambda_function_output_path = "${path.module}/../functions/builds/crawl.zip"
  lambda_file_name            = "${path.module}/../functions/builds/crawl.zip"
  lambda_role_arn             = aws_iam_role.lambda_exec_role.arn
  handler                     = "lambda_function.lambda_handler"
  timeout                     = 900
  memory_size                 = 128

}

module "lambda_download" {
  source                      = "./modules/lambda"
  lambda_function_name        = "lambda-download"
  lambda_function_source_dir  = "${path.module}/../functions/download"
  lambda_function_output_path = "${path.module}/../functions/builds/download.zip"
  lambda_file_name            = "${path.module}/../functions/builds/download.zip"
  lambda_role_arn             = aws_iam_role.lambda_exec_role.arn
  handler                     = "lambda_function.lambda_handler"
  timeout                     = 900
  memory_size                 = 128

  lambda_environment_variables = {
    BUCKET = module.s3_bucket.bucket_name
  }
}

module "lambda_load" {
  source                      = "./modules/lambda"
  lambda_function_name        = "lambda-load"
  lambda_function_source_dir  = "${path.module}/../functions/load"
  lambda_function_output_path = "${path.module}/../functions/builds/load.zip"
  lambda_file_name            = "${path.module}/../functions/builds/load.zip"
  lambda_role_arn             = aws_iam_role.lambda_exec_role.arn
  handler                     = "lambda_function.lambda_handler"
  timeout                     = 900
  memory_size                 = 128

  lambda_environment_variables = {
    BUCKET  = module.s3_bucket.bucket_name
    GRAPHDB = "${var.graphdb_url}"
    REPO    = "${var.repo_name}"
  }
}

resource "aws_sfn_state_machine" "rdf_pipeline" {
  name     = "rdf-pipeline"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    Comment = "RDF crawl -> download (fan-out) -> load"
    StartAt = "Crawl"
    States = {
      Crawl = {
        Type     = "Task"
        Resource = module.lambda_crawl.lambda_arn
        Next     = "Download"
      }
      Download = {
        Type           = "Map"
        ItemsPath      = "$.profiles"
        MaxConcurrency = 5
        Iterator = {
          StartAt = "DownloadFile"
          States = {
            DownloadFile = {
              Type     = "Task"
              Resource = module.lambda_download.lambda_arn
              Next     = "Load"
            }
            Load = {
              Type     = "Task"
              Resource = module.lambda_load.lambda_arn
              End      = true
            }
          }
        }
        ResultPath = null
        End        = true
      }

    }
  })

  tags = {
    Project = "rdf"
  }
}

resource "aws_cloudwatch_event_rule" "rdf_weekly_trigger" {
  name                = "rdf-pipeline-weekly"
  description         = "Triggers the RDF pipeline once a week"
  schedule_expression = "cron(0 6 ? * MON *)"
}

resource "aws_cloudwatch_event_target" "rdf_pipeline_target" {
  rule      = aws_cloudwatch_event_rule.rdf_weekly_trigger.name
  target_id = "rdf-pipeline"
  arn       = aws_sfn_state_machine.rdf_pipeline.arn
  role_arn  = aws_iam_role.eventbridge_sfn_role.arn

  input = jsonencode({
    "url" : "${var.crawl_url}"
  })
}
