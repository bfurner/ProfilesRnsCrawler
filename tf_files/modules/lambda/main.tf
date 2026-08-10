# create archive file for deployment
data "archive_file" "lambda_function" {
  source_dir = "${var.lambda_function_source_dir}"
  output_path = "${var.lambda_function_output_path}"
  type        = "zip"
  excludes = [
    "__pycache__"
  ]
}

# declare the lambda function
resource "aws_lambda_function" "lambda_function_definition" {
  filename         = "${var.lambda_file_name}"
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  function_name    = "${var.lambda_function_name}"
  role             = "${var.lambda_role_arn}"
  handler          = "${var.handler}"
  runtime          = "${var.runtime}"
  timeout          = var.timeout
  memory_size      = var.memory_size
  layers           = length(var.layers) > 0 ? var.layers : null

  
  dynamic "vpc_config" {
    for_each = var.enable_vpc ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [var.security_group_id]
    }
  }

  dynamic "file_system_config" {
    for_each = var.enable_efs ? [1] : []
    content {
      arn              = var.efs_arn
      local_mount_path = "/mnt/efs"
    }
  }
  
  ephemeral_storage {
    size = var.lambda_tmp_size != 512 ? var.lambda_tmp_size : 512
  }

  environment {
    variables = var.lambda_environment_variables
  }

  tags = var.tags
}

# explicitly create the log group in order to set retention period
# otherwise it will default to never expire
resource "aws_cloudwatch_log_group" "lambda_function_log_group" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 180
  tags = "${var.tags}"
}











