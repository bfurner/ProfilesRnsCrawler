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

output "ecs_cluster_arn" {
  value = module.ecs_fargate[0].cluster_arn
}

output "ecs_task_definition_arn" {
  value = module.ecs_fargate[0].task_definition_arn
}

output "schedule_expression" {
  value = var.schedule_expression
}

output "failure_topic_arn" {
  description = "SNS topic for failure notifications (null if no emails configured)"
  value       = length(var.notification_emails) > 0 ? module.sns_failure_topic[0].topic_arn : null
}
