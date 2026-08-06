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

# IAM role assumed by the ECS Fargate task (S3, SSM, logs).
resource "aws_iam_role" "ecs_task_role" {
  name = var.ecs_task_role

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

# Permissions for the ECS task role.
resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "${var.ecs_task_role}-policy"
  role = aws_iam_role.ecs_task_role.id

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

# Attach the AWS-managed ECS task execution policy (pull images, write logs).
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM role assumed by EventBridge to start the ECS task.
resource "aws_iam_role" "eventbridge_ecs_role" {
  name = var.eventbridge_ecs_role

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

# Permissions for EventBridge to RunTask and PassRole.
resource "aws_iam_role_policy" "eventbridge_ecs_policy" {
  name = "${var.eventbridge_ecs_role}-policy"
  role = aws_iam_role.eventbridge_ecs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = [
          module.ecs_fargate[0].task_definition_arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.ecs_task_role.arn
      }
    ]
  })
}

# One-shot Fargate task (no long-running service) that runs LoadToGraphDB.
module "ecs_fargate" {
  source = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/ecs?ref=0.5.1"

  app_name               = var.ecs_app_name
  app_port               = var.app_port
  app_image              = "${module.ecr_loader.repo_url}:${var.app_tag}"
  ecs_execution_role_arn = aws_iam_role.ecs_task_role.arn
  security_group_id      = var.security_group_id
  subnet_ids             = var.subnet_ids
  assign_public_ip       = var.assign_public_ip
  single_execution       = true
  include_service        = false

  environment_vars = [
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

  count = 1
}

# Weekly EventBridge schedule that starts the ECS loader task.
module "ecs_fargate_trigger" {
  source = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/eventbridge_ecs_trigger?ref=0.5.1"

  event_rule_name     = var.ecs_trigger_event_rule_name
  schedule_expression = var.schedule_expression
  ecs_cluster_arn     = module.ecs_fargate[0].cluster_arn
  role_arn            = aws_iam_role.eventbridge_ecs_role.arn
  task_definition_arn = module.ecs_fargate[0].task_definition_arn
  security_group_id   = var.security_group_id
  subnet_ids          = var.subnet_ids

  count = 1
}

# Optional SNS topic for failure email notifications.
module "sns_failure_topic" {
  source = "git::ssh://git@github.com/chicagopcdc/terraform_modules.git//aws/sns?ref=0.5.1"

  notification_emails = var.notification_emails
  topic_name          = var.failure_notification_topic

  count = length(var.notification_emails) > 0 ? 1 : 0
}
