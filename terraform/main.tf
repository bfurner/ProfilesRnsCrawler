# Staging bucket for RDF files consumed by the weekly loader.
module "s3_rdf" {
  source = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/s3?ref=1.0.5"

  bucket_name      = var.bucket_name
  force_delete     = var.force_delete
  versioning       = var.s3_versioning
  encryption       = var.s3_encryption
  enable_lifecycle = var.s3_enable_lifecycle
}

# ECR repository for the LoadToGraphDB container image.
module "ecr_loader" {
  source = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/ecr?ref=1.0.5"

  repo_name    = var.ecr_repo_name
  force_delete = var.force_delete
}

# SSM SecureString holding the GraphDB password used by the loader.
resource "aws_ssm_parameter" "graphdb_password" {
  name  = var.graphdb_password_ssm_name
  type  = "SecureString"
  value = var.graphdb_password

  tags = var.default_tags

  lifecycle {
    ignore_changes = [value]
  }
}

# CloudWatch log group for Batch job container logs.
resource "aws_cloudwatch_log_group" "batch" {
  name              = var.batch_log_group_name
  retention_in_days = 7

  tags = var.default_tags
}

# IAM role for the AWS Batch service (managed compute environment).
resource "aws_iam_role" "batch_service" {
  name = var.batch_service_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "batch.amazonaws.com"
        }
      }
    ]
  })

  tags = var.default_tags
}

resource "aws_iam_role_policy_attachment" "batch_service" {
  role       = aws_iam_role.batch_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

# IAM role assumed by the Batch job container (S3, SSM, logs).
resource "aws_iam_role" "batch_job" {
  name = var.batch_job_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.default_tags
}

# Permissions for the Batch job role.
resource "aws_iam_role_policy" "batch_job" {
  name = "${var.batch_job_role}-policy"
  role = aws_iam_role.batch_job.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.s3_rdf.bucket_arn,
          "${module.s3_rdf.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          aws_ssm_parameter.graphdb_password.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Execution role for Fargate Batch (pull ECR image, write logs).
resource "aws_iam_role" "batch_execution" {
  name = var.batch_execution_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.default_tags
}

resource "aws_iam_role_policy_attachment" "batch_execution" {
  role       = aws_iam_role.batch_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM role assumed by EventBridge to submit Batch jobs.
resource "aws_iam_role" "eventbridge_batch" {
  name = var.eventbridge_batch_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = var.default_tags
}

# Permissions for EventBridge to SubmitJob and PassRole.
resource "aws_iam_role_policy" "eventbridge_batch" {
  name = "${var.eventbridge_batch_role}-policy"
  role = aws_iam_role.eventbridge_batch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "batch:SubmitJob"
        ]
        Resource = [
          aws_batch_job_queue.loader.arn,
          aws_batch_job_definition.loader.arn
        ]
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.batch_job.arn,
          aws_iam_role.batch_execution.arn
        ]
      }
    ]
  })
}

# Managed Fargate compute environment for Batch.
resource "aws_batch_compute_environment" "loader" {
  compute_environment_name = var.batch_compute_environment_name
  type                     = "MANAGED"
  state                    = "ENABLED"

  service_role = aws_iam_role.batch_service.arn

  compute_resources {
    type               = "FARGATE"
    max_vcpus          = var.batch_max_vcpus
    subnets            = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  depends_on = [aws_iam_role_policy_attachment.batch_service]

  tags = var.default_tags
}

# Job queue backed by the Fargate compute environment.
resource "aws_batch_job_queue" "loader" {
  name     = var.batch_job_queue_name
  state    = "ENABLED"
  priority = 1

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.loader.arn
  }

  tags = var.default_tags
}

# Job definition that runs the LoadToGraphDB container image.
resource "aws_batch_job_definition" "loader" {
  name                  = var.batch_job_definition_name
  type                  = "container"
  platform_capabilities = ["FARGATE"]

  container_properties = jsonencode({
    image            = "${module.ecr_loader.repo_url}:${var.app_tag}"
    jobRoleArn       = aws_iam_role.batch_job.arn
    executionRoleArn = aws_iam_role.batch_execution.arn
    resourceRequirements = [
      {
        type  = "VCPU"
        value = tostring(var.batch_vcpu)
      },
      {
        type  = "MEMORY"
        value = tostring(var.batch_memory)
      }
    ]
    networkConfiguration = {
      assignPublicIp = var.assign_public_ip ? "ENABLED" : "DISABLED"
    }
    environment = [
      {
        name  = "RDF_S3_BUCKET"
        value = module.s3_rdf.bucket_name
      },
      {
        name  = "RDF_S3_PREFIX"
        value = var.rdf_s3_prefix
      },
      {
        name  = "LOAD_PATHS"
        value = var.load_paths
      },
      {
        name  = "GRAPHDB_BASE_URL"
        value = var.graphdb_base_url
      },
      {
        name  = "GRAPHDB_REPO"
        value = var.graphdb_repo
      },
      {
        name  = "GRAPHDB_USERNAME"
        value = var.graphdb_username
      },
      {
        name  = "GRAPHDB_PASSWORD_SSM_PARAM"
        value = aws_ssm_parameter.graphdb_password.name
      },
      {
        name  = "AWS_REGION"
        value = var.aws_region
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "batch"
      }
    }
  })

  tags = var.default_tags
}

# Weekly EventBridge schedule that submits the Batch job.
resource "aws_cloudwatch_event_rule" "batch_schedule" {
  name                = var.batch_trigger_event_rule_name
  description         = "Weekly schedule to submit the GraphDB RDF load Batch job"
  schedule_expression = var.schedule_expression

  tags = var.default_tags
}

resource "aws_cloudwatch_event_target" "batch_schedule" {
  rule     = aws_cloudwatch_event_rule.batch_schedule.name
  arn      = aws_batch_job_queue.loader.arn
  role_arn = aws_iam_role.eventbridge_batch.arn

  batch_target {
    job_definition = aws_batch_job_definition.loader.arn
    job_name       = var.batch_scheduled_job_name
  }
}

# Optional SNS topic for failure email notifications.
module "sns_failure_topic" {
  source = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/sns?ref=0.5.1"

  notification_emails = var.notification_emails
  topic_name          = var.failure_notification_topic

  count = length(var.notification_emails) > 0 ? 1 : 0
}
