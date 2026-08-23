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

variable "batch_compute_environment_name" {
  type        = string
  description = "AWS Batch compute environment name"
}

variable "batch_job_queue_name" {
  type        = string
  description = "AWS Batch job queue name"
}

variable "batch_job_definition_name" {
  type        = string
  description = "AWS Batch job definition name"
}

variable "batch_scheduled_job_name" {
  type        = string
  description = "Job name used when EventBridge submits the Batch job"
}

variable "batch_service_role" {
  type        = string
  description = "IAM role name for the AWS Batch service"
}

variable "batch_job_role" {
  type        = string
  description = "IAM role name assumed by the Batch job container"
}

variable "batch_execution_role" {
  type        = string
  description = "IAM execution role name for Fargate Batch (ECR pull / logs)"
}

variable "eventbridge_batch_role" {
  type        = string
  description = "IAM role name for EventBridge to submit Batch jobs"
}

variable "batch_trigger_event_rule_name" {
  type        = string
  description = "EventBridge rule name for the weekly Batch trigger"
}

variable "batch_log_group_name" {
  type        = string
  description = "CloudWatch log group for Batch job logs"
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
  description = "Docker image tag to run in Batch"
  default     = "latest"
}

variable "batch_max_vcpus" {
  type        = number
  description = "Max vCPUs for the Batch Fargate compute environment"
  default     = 4
}

variable "batch_vcpu" {
  type        = number
  description = "vCPUs reserved for each Batch job"
  default     = 0.25
}

variable "batch_memory" {
  type        = number
  description = "Memory (MiB) reserved for each Batch job"
  default     = 512
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
  description = "EventBridge schedule for the GraphDB load job (weekly by default)"
  default     = "cron(0 12 ? * SUN *)" # Sundays 12:00 UTC
}

variable "security_group_id" {
  type        = string
  description = "Security group for the Batch job (must allow egress to GraphDB and S3/SSM endpoints)"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the Batch Fargate compute environment. If assign_public_ip is false, these must have NAT (or VPC endpoints) for egress."
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign a public IP to the Fargate Batch job. Set false only when the chosen subnets already have NAT (or VPC endpoints) for ECR/S3/SSM/GraphDB egress."
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
