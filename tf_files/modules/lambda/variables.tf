variable "lambda_function_name" {
  type = string
  description = "The lambda function name"
}

variable "lambda_function_source_dir" {
  type        = string
  description = "the path to the source file for the lambda"
}

variable "lambda_function_output_path" {
  type        = string
  description = "Th path to the output file for the bundle archive for the lambda to load"
}

variable "lambda_file_name" {
  type = string
  description = "the name of the file associated with the lambda"
}

variable "lambda_role_arn" {
  type = string
  description = "the ARN of the role associated to the lambda"
}

variable "handler" {
  type = string
  description = "the function handler in the lambda"
}

variable "timeout" {
  type = string
  description = "lamda timeout limit"
}

variable "memory_size" {
  type = string
  description = "memory allocated for the lambda"
}

variable "runtime" {
  type = string
  description = "the runtime version for the lambda"
  default     = "python3.9"
}

variable "enable_vpc" {
  description = "Whether to enable VPC configuration for the Lambda function"
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Lambda function"
  type        = list(string)
  default     = []

  validation {
    condition     = !var.enable_vpc || length(var.subnet_ids) > 0
    error_message = "If enable_vpc is true, subnet_ids must be provided and non-empty."
  }
}

variable "security_group_id" {
  description = "Security group ID for the Lambda function"
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_vpc || var.security_group_id != ""
    error_message = "If enable_vpc is true, security_group_id must be provided and non-empty."
  }
}

variable "lambda_environment_variables" {
  type = map(string)
  description = "the ENV variable passed to the lambda"
  default     = {}
}

variable "tags" {
  description = "resources tags"
  type        = map(string)
  default     = {}
}

variable "enable_efs" {
  description = "Whether to attach EFS to Lambda"
  type        = bool
  default     = false
}

variable "efs_arn" {
  description = "EFS Access Point ARN to attach to Lambda"
  type        = string
  default     = ""
}

variable "layers" {
  description = "List of Lambda layer ARNs to attach to the function"
  type        = list(string)
  default     = []
}

variable "lambda_tmp_size" {
  description = "Size of the Lambda ephemeral storage in MB (512–10240)."
  type        = number
  default     = 512
}


/*
locals {
  invalid_vpc_subnet_ids = var.enable_vpc && length(var.subnet_ids) == 0
  invalid_vpc_sg         = var.enable_vpc && var.security_group_id == ""
}

resource "null_resource" "validate_lambda_vpc_inputs" {
  count = local.invalid_vpc_subnet_ids || local.invalid_vpc_sg ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
      >&2 echo "ERROR: If enable_vpc is true, you must provide non-empty subnet_ids and security_group_id."
      exit 1
    EOT
  }
}
*/
