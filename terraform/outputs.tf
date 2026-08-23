output "rdf_bucket_name" {
  description = "S3 bucket where RDF files should be uploaded for the weekly loader"
  value       = module.s3_rdf.bucket_name
}

output "rdf_bucket_arn" {
  value = module.s3_rdf.bucket_arn
}

output "repo_url" {
  description = "ECR repository URL for the LoadToGraphDB container image"
  value       = module.ecr_loader.repo_url
}

output "graphdb_password_ssm_parameter" {
  description = "SSM SecureString parameter name holding the GraphDB password"
  value       = aws_ssm_parameter.graphdb_password.name
}

output "batch_compute_environment_arn" {
  value = aws_batch_compute_environment.loader.arn
}

output "batch_job_queue_arn" {
  value = aws_batch_job_queue.loader.arn
}

output "batch_job_definition_arn" {
  value = aws_batch_job_definition.loader.arn
}

output "batch_log_group_name" {
  value = aws_cloudwatch_log_group.batch.name
}

output "schedule_expression" {
  value = var.schedule_expression
}

output "batch_trigger_event_rule_name" {
  value = aws_cloudwatch_event_rule.batch_schedule.name
}

output "failure_topic_arn" {
  description = "SNS topic for failure notifications (null if no emails configured)"
  value       = length(var.notification_emails) > 0 ? module.sns_failure_topic[0].topic_arn : null
}
