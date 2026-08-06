variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "app_name" {
  type        = string
  description = "Application name (for tags / documentation)"
  default     = "profiles-rns-graphdb"
}

variable "env_name" {
  type        = string
  description = "Environment tier (e.g. staging, prod)"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket name for RDF staging"
}

variable "ecr_repo_name" {
  type        = string
  description = "ECR repository name for the LoadToGraphDB image"
}

variable "ecs_app_name" {
  type        = string
  description = "Name prefix passed to the ECS module (cluster/task family naming)"
}

variable "ecs_task_role" {
  type        = string
  description = "IAM role name for the ECS task"
}

variable "eventbridge_ecs_role" {
  type        = string
  description = "IAM role name for EventBridge to run ECS tasks"
}

variable "ecs_trigger_event_rule_name" {
  type        = string
  description = "EventBridge rule name for the weekly ECS trigger"
}

variable "graphdb_password_ssm_name" {
  type        = string
  description = "SSM SecureString parameter name for the GraphDB password"
}

variable "failure_notification_topic" {
  type        = string
  description = "SNS topic name for failure notifications"
}

variable "app_tag" {
  type        = string
  description = "Docker image tag to run in ECS"
  default     = "latest"
}

variable "app_port" {
  type        = number
  description = "Container port expected by the ECS module (unused by the loader, but required)"
  default     = 8080
}

variable "force_delete" {
  type        = bool
  description = "Allow force-delete of S3/ECR on destroy"
  default     = false
}

variable "s3_versioning" {
  type        = string
  description = "S3 versioning status: Enabled or Disabled"
  default     = "Enabled"
}

variable "s3_encryption" {
  type        = bool
  description = "Enable S3 default encryption"
  default     = true
}

variable "s3_enable_lifecycle" {
  type        = bool
  description = "Enable S3 lifecycle expiration rules"
  default     = false
}

variable "schedule_expression" {
  type        = string
  description = "EventBridge schedule for the GraphDB load task (weekly by default)"
  default     = "cron(0 12 ? * SUN *)" # Sundays 12:00 UTC
}

variable "security_group_id" {
  type        = string
  description = "Security group for the ECS task (must allow egress to GraphDB and S3/SSM endpoints)"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the ECS task ENIs"
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign a public IP to the Fargate task (needed if subnets have no NAT for S3/GraphDB egress)"
  default     = true
}

variable "graphdb_base_url" {
  type        = string
  description = "GraphDB Workbench / REST base URL, e.g. https://graphdb.example.org:7200"
}

variable "graphdb_repo" {
  type        = string
  description = "GraphDB repository id"
  default     = "profiles"
}

variable "graphdb_username" {
  type        = string
  description = "GraphDB username when security is enabled"
  default     = "admin"
}

variable "graphdb_password" {
  type        = string
  description = "Initial GraphDB password stored in SSM (ignored after first apply if lifecycle ignore_changes is used)"
  sensitive   = true
}

variable "rdf_s3_prefix" {
  type        = string
  description = "S3 key prefix under the RDF bucket to sync before loading (e.g. rdf/ or empty for whole bucket)"
  default     = "rdf/"
}

variable "load_paths" {
  type        = string
  description = "Paths passed to LoadToGraphDB.py inside the container (space-separated)"
  default     = "/data/rdf"
}

variable "notification_emails" {
  type        = list(string)
  description = "Emails subscribed to task-failure SNS topic (empty disables SNS module usage for alerts wiring)"
  default     = []
}

variable "default_tags" {
  type        = map(string)
  description = "Tags applied to supported resources"
  default     = {}
}
