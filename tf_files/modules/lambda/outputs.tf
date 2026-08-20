output "lambda_arn" {
  description = "the ARN of the lambda"
  value       = aws_lambda_function.lambda_function_definition.arn
}

output "lambda_log_group" {
  description = "The log group associated with the lambda"
  value       = aws_cloudwatch_log_group.lambda_function_log_group.name
}

output "lambda_name" {
  description = "The name of the lambda"
  value       = aws_lambda_function.lambda_function_definition.function_name
}

output "lambda_invoke_arn" {
  description = "The name of the lambda"
  value       = aws_lambda_function.lambda_function_definition.invoke_arn
}