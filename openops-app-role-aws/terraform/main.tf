# OpenOps App IAM Role
#
# Creates the IAM role (and relevant permissions) used by the OpenOps app,
# and can optionally configure cost management services, like Cost Explorer,
# Compute Optimizer, Cost Optimization Hub, and CUR.
#
# The Read Access policy allows the role to know basic information about
# resources, without access to secrets. Other permission policies can
# optionally be disabled via variables.
#
# Apply in the us-east-1 region when cost_usage_report is enabled,
# as CUR is only available in that region.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "aws_account_id" {
  type        = string
  description = "An AWS Account ID that would be allowed to assume the OpenOps role in this account."

  validation {
    condition     = can(regex("^\\d{12}$", var.aws_account_id))
    error_message = "Account ID must be a 12-digit number."
  }
}

variable "external_id" {
  type        = string
  description = "Optional external ID required to assume the OpenOps role. Recommended for security when the role is assumed from another account."
  default     = ""
  sensitive   = true
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role (and instance profile) created for OpenOps."
  default     = "OpenOpsApp"
}

variable "cost_usage_report" {
  type        = bool
  description = "Create the Cost and Usage Report and export it to an S3 bucket."
  default     = true
}

variable "optimization_hub_configuration_access" {
  type        = bool
  description = "Allow OpenOps to enroll the account to the Cost Optimization Hub, if it's not already enabled."
  default     = true
}

variable "tagging_access" {
  type        = bool
  description = "Allow OpenOps to add, update and remove resource tags, such as resource owners."
  default     = true
}

variable "ec2_instance_optimization_access" {
  type        = bool
  description = "Allow OpenOps to optimize EC2 instances, such as stopping or terminating underutilized instances."
  default     = true
}

variable "volume_optimization_access" {
  type        = bool
  description = "Allow OpenOps to optimize EBS volumes, such as deleting unattached volumes or upgrading gp2 to gp3."
  default     = true
}

variable "rds_optimization_access" {
  type        = bool
  description = "Allow OpenOps to optimize RDS instances, such as stopping or terminating underutilized instances."
  default     = true
}

variable "stack_optimization_access" {
  type        = bool
  description = "Allow OpenOps to optimize resources by updating CloudFormation stacks."
  default     = true
}

variable "cloudfront_optimization_access" {
  type        = bool
  description = "Allow OpenOps to optimize CloudFront distributions."
  default     = true
}

variable "create_iam_user" {
  type        = bool
  description = "Create an IAM user with the same permissions as the role, including the ability to assume the role."
  default     = false
}

# ---------------------------------------------------------------------------
# Data sources and locals
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  cur_bucket_name = "openops-cur-${data.aws_caller_identity.current.account_id}"

  assume_role_policy = {
    Version = "2012-10-17"
    Statement = concat(
      [
        merge(
          {
            Effect    = "Allow"
            Principal = { AWS = var.aws_account_id }
            Action    = "sts:AssumeRole"
          },
          var.external_id != "" ? {
            Condition = { StringEquals = { "sts:ExternalId" = var.external_id } }
          } : {}
        ),
      ],
      var.create_iam_user ? [
        {
          Effect    = "Allow"
          Principal = { AWS = aws_iam_user.openops_app[0].arn }
          Action    = "sts:AssumeRole"
        },
      ] : [],
      [
        {
          Effect    = "Allow"
          Principal = { Service = "ec2.amazonaws.com" }
          Action    = "sts:AssumeRole"
        },
      ]
    )
  }

  resource_optimization_statements = concat(
    [
      {
        Sid      = "PlaceholderStatement"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
    ],
    var.tagging_access ? [
      {
        Sid    = "TaggingAccess"
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "tag:*",
          "rds:AddTagsToResource",
          "rds:RemoveTagsFromResource",
          "resource-groups:Tag*",
          "resource-groups:Untag*",
        ]
        Resource = "*"
      },
    ] : [],
    var.ec2_instance_optimization_access ? [
      {
        Sid    = "Ec2InstanceOptimizationAccess"
        Effect = "Allow"
        Action = [
          "ec2:ModifyInstance*",
          "ec2:ModifyLaunchTemplate",
          "ec2:RebootInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:TerminateInstances",
        ]
        Resource = "*"
      },
    ] : [],
    var.volume_optimization_access ? [
      {
        Sid    = "VolumeOptimizationAccess"
        Effect = "Allow"
        Action = [
          "ec2:AttachVolume",
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DeleteVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:ModifyVolumeAttribute",
        ]
        Resource = "*"
      },
    ] : [],
    var.rds_optimization_access ? [
      {
        Sid    = "RdsOptimizationAccess"
        Effect = "Allow"
        Action = [
          "rds:CreateDBSnapshot",
          "rds:Delete*",
          "rds:Modify*",
          "rds:Reboot*",
          "rds:Start*",
          "rds:Stop*",
          "rds:AddTagsToResource",
        ]
        Resource = "*"
      },
    ] : [],
    var.stack_optimization_access ? [
      {
        Sid    = "StackOptimizationAccess"
        Effect = "Allow"
        Action = [
          "cloudformation:Cancel*",
          "cloudformation:Delete*",
          "cloudformation:Update*",
        ]
        Resource = "*"
      },
    ] : [],
    var.cloudfront_optimization_access ? [
      {
        Sid    = "CloudFrontOptimizationAccess"
        Effect = "Allow"
        Action = [
          "cloudfront:UpdateDistribution",
        ]
        Resource = "*"
      },
    ] : []
  )
}

# ---------------------------------------------------------------------------
# IAM role and instance profile
# ---------------------------------------------------------------------------

resource "aws_iam_role" "openops_app" {
  name               = var.role_name
  assume_role_policy = jsonencode(local.assume_role_policy)
}

resource "aws_iam_instance_profile" "openops_app" {
  name = var.role_name
  path = "/"
  role = aws_iam_role.openops_app.name
}

# ---------------------------------------------------------------------------
# Read access policy
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "read_access" {
  name = "${var.role_name}-ReadAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CoreReadAccess"
        Effect = "Allow"
        Action = [
          "ec2:DescribeRegions",
          "sts:GetCallerIdentity",
          "organizations:DescribeAccount",
          "organizations:DescribeOrganization",
          "organizations:ListAccounts",
          "pricing:Describe*",
          "pricing:Get*",
          "pricing:List*",
          "iam:ListTagsForResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchReadAccess"
        Effect = "Allow"
        Action = [
          "application-autoscaling:DescribeScalingPolicies",
          "autoscaling:Describe*",
          "cloudwatch:BatchGet*",
          "cloudwatch:Describe*",
          "cloudwatch:GenerateQuery",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "logs:Get*",
          "logs:List*",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:Describe*",
          "logs:TestMetricFilter",
          "logs:FilterLogEvents",
          "oam:ListSinks",
          "sns:Get*",
          "sns:List*",
          "rum:BatchGet*",
          "rum:Get*",
          "rum:List*",
          "synthetics:Describe*",
          "synthetics:Get*",
          "synthetics:List*",
          "xray:BatchGet*",
          "xray:Get*",
        ]
        Resource = "*"
      },
      {
        Sid    = "OptimizationHubReadAccess"
        Effect = "Allow"
        Action = [
          "compute-optimizer:Get*",
          "compute-optimizer:Describe*",
          "cost-optimization-hub:Get*",
          "cost-optimization-hub:List*",
          "trustedadvisor:Describe*",
          "trustedadvisor:Get*",
          "trustedadvisor:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "CostExplorerReadAccess"
        Effect = "Allow"
        Action = [
          "ce:Describe*",
          "ce:Get*",
          "ce:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "ComputeReadAccess"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:Get*",
          "ec2:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "EcsReadAccess"
        Effect = "Allow"
        Action = [
          "ecs:Describe*",
          "ecs:List*",
          "ecr:BatchCheck*",
          "ecr:BatchGet*",
          "ecr:Get*",
          "ecr:Describe*",
          "ecr:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "EksReadAccess"
        Effect = "Allow"
        Action = [
          "eks:Describe*",
          "eks:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaReadAccess"
        Effect = "Allow"
        Action = [
          "lambda:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "LoadBalancersReadAccess"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:Describe*",
        ]
        Resource = "*"
      },
      {
        Sid    = "RdsClustersReadAccess"
        Effect = "Allow"
        Action = [
          "rds:Describe*",
          "rds:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudFrontReadAccess"
        Effect = "Allow"
        Action = [
          "cloudfront:List*",
          "cloudfront:Get*",
        ]
        Resource = "*"
      },
      {
        Sid    = "S3ReadAccess"
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "MqReadAccess"
        Effect = "Allow"
        Action = [
          "mq:Describe*",
          "mq:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "ReservationsAndSavingPlansReadAccess"
        Effect = "Allow"
        Action = [
          "ec2:DescribeReserved*",
          "elasticache:DescribeReserved*",
          "redshift:DescribeReserved*",
          "rds:DescribeReserved*",
          "savingsplans:Describe*",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudTrailReadAccess"
        Effect = "Allow"
        Action = [
          "cloudtrail:CancelQuery",
          "cloudtrail:Describe*",
          "cloudtrail:Get*",
          "cloudtrail:LookupEvents",
          "cloudtrail:StartQuery",
          "config:DescribeConfigurationRecorderStatus",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudFormationReadAccess"
        Effect = "Allow"
        Action = [
          "cloudformation:Describe*",
          "cloudformation:Get*",
          "cloudformation:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "DynamoDbReadAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:Describe*",
          "dynamodb:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "SsmReadAccess"
        Effect = "Allow"
        Action = [
          "ssm:Describe*",
          "ssm:List*",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "read_access" {
  role       = aws_iam_role.openops_app.name
  policy_arn = aws_iam_policy.read_access.arn
}

resource "aws_iam_user_policy_attachment" "read_access" {
  count      = var.create_iam_user ? 1 : 0
  user       = aws_iam_user.openops_app[0].name
  policy_arn = aws_iam_policy.read_access.arn
}

# ---------------------------------------------------------------------------
# Resource optimization policy
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "resource_optimization" {
  name = "${var.role_name}-ResourceOptimizationAccess"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.resource_optimization_statements
  })
}

resource "aws_iam_role_policy_attachment" "resource_optimization" {
  role       = aws_iam_role.openops_app.name
  policy_arn = aws_iam_policy.resource_optimization.arn
}

resource "aws_iam_user_policy_attachment" "resource_optimization" {
  count      = var.create_iam_user ? 1 : 0
  user       = aws_iam_user.openops_app[0].name
  policy_arn = aws_iam_policy.resource_optimization.arn
}

# ---------------------------------------------------------------------------
# Optimization Hub configuration policy
# ---------------------------------------------------------------------------

resource "aws_iam_policy" "optimization_hub_configuration" {
  count = var.optimization_hub_configuration_access ? 1 : 0
  name  = "${var.role_name}-OptimizationHubConfiguration"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CreateServiceRoleForComputeOptimizer"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::*:role/aws-service-role/compute-optimizer.amazonaws.com/AWSServiceRoleForComputeOptimizer"
      },
      {
        Sid    = "EnrollToCostOptimizationHub"
        Effect = "Allow"
        Action = [
          "compute-optimizer:UpdateEnrollmentStatus",
          "cost-optimization-hub:UpdateEnrollmentStatus",
          "cost-optimization-hub:UpdatePreferences",
          "trustedadvisor:RefreshCheck",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "optimization_hub_configuration" {
  count      = var.optimization_hub_configuration_access ? 1 : 0
  role       = aws_iam_role.openops_app.name
  policy_arn = aws_iam_policy.optimization_hub_configuration[0].arn
}

resource "aws_iam_user_policy_attachment" "optimization_hub_configuration" {
  count      = var.optimization_hub_configuration_access && var.create_iam_user ? 1 : 0
  user       = aws_iam_user.openops_app[0].name
  policy_arn = aws_iam_policy.optimization_hub_configuration[0].arn
}

# ---------------------------------------------------------------------------
# Cost and Usage Report (CUR)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "cur" {
  count  = var.cost_usage_report ? 1 : 0
  bucket = local.cur_bucket_name
}

resource "aws_s3_bucket_lifecycle_configuration" "cur" {
  count  = var.cost_usage_report ? 1 : 0
  bucket = aws_s3_bucket.cur[0].id

  rule {
    id     = "TransitionToInfrequentAccess"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "ExpireOldReports"
    status = "Enabled"

    filter {}

    expiration {
      days = 180
    }
  }
}

resource "aws_s3_bucket_policy" "cur" {
  count  = var.cost_usage_report ? 1 : 0
  bucket = aws_s3_bucket.cur[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowBillingReportsAccess"
        Effect    = "Allow"
        Principal = { Service = "billingreports.amazonaws.com" }
        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketPolicy",
          "s3:PutObject",
        ]
        Resource = [
          aws_s3_bucket.cur[0].arn,
          "${aws_s3_bucket.cur[0].arn}/*",
        ]
      },
    ]
  })
}

# CUR report definitions are only available in the us-east-1 region.
resource "aws_cur_report_definition" "openops" {
  count = var.cost_usage_report ? 1 : 0

  report_name                = "OpenOpsHourlyAthena"
  time_unit                  = "HOURLY"
  format                     = "Parquet"
  compression                = "Parquet"
  additional_schema_elements = ["RESOURCES"]
  additional_artifacts       = ["ATHENA"]
  s3_bucket                  = aws_s3_bucket.cur[0].id
  s3_prefix                  = "openops-reports"
  s3_region                  = "us-east-1"
  refresh_closed_reports     = true
  report_versioning          = "OVERWRITE_REPORT"

  depends_on = [aws_s3_bucket_policy.cur]
}

resource "aws_iam_policy" "cur_access" {
  count = var.cost_usage_report ? 1 : 0
  name  = "${var.role_name}-CurAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CurReadAccess"
        Effect = "Allow"
        Action = [
          "cur:Describe*",
          "cur:Get*",
          "cur:ValidateReportDestination",
        ]
        Resource = "*"
      },
      {
        Sid    = "CurBucketReadAccess"
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.cur[0].arn,
          "${aws_s3_bucket.cur[0].arn}/*",
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cur_access" {
  count      = var.cost_usage_report ? 1 : 0
  role       = aws_iam_role.openops_app.name
  policy_arn = aws_iam_policy.cur_access[0].arn
}

resource "aws_iam_user_policy_attachment" "cur_access" {
  count      = var.cost_usage_report && var.create_iam_user ? 1 : 0
  user       = aws_iam_user.openops_app[0].name
  policy_arn = aws_iam_policy.cur_access[0].arn
}

# ---------------------------------------------------------------------------
# Optional IAM user
# ---------------------------------------------------------------------------

resource "aws_iam_user" "openops_app" {
  count = var.create_iam_user ? 1 : 0
  name  = var.role_name
  path  = "/"
}

resource "aws_iam_access_key" "openops_app" {
  count = var.create_iam_user ? 1 : 0
  user  = aws_iam_user.openops_app[0].name
}

resource "aws_secretsmanager_secret" "openops_app_user" {
  count       = var.create_iam_user ? 1 : 0
  name        = "openops-app-user-credentials-${data.aws_caller_identity.current.account_id}"
  description = "API credentials for the OpenOps App IAM User"
}

resource "aws_secretsmanager_secret_version" "openops_app_user" {
  count     = var.create_iam_user ? 1 : 0
  secret_id = aws_secretsmanager_secret.openops_app_user[0].id

  secret_string = jsonencode({
    AccessKeyId     = aws_iam_access_key.openops_app[0].id
    SecretAccessKey = aws_iam_access_key.openops_app[0].secret
  })
}

resource "aws_iam_policy" "secrets_access" {
  count = var.create_iam_user ? 1 : 0
  name  = "${var.role_name}-SecretsAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = aws_secretsmanager_secret.openops_app_user[0].arn
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "secrets_access" {
  count      = var.create_iam_user ? 1 : 0
  user       = aws_iam_user.openops_app[0].name
  policy_arn = aws_iam_policy.secrets_access[0].arn
}

resource "aws_iam_policy" "assume_role" {
  count = var.create_iam_user ? 1 : 0
  name  = "${var.role_name}-AssumeRole"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.openops_app.arn
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "assume_role" {
  count      = var.create_iam_user ? 1 : 0
  user       = aws_iam_user.openops_app[0].name
  policy_arn = aws_iam_policy.assume_role[0].arn
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "iam_role_arn" {
  description = "The ARN of the IAM role created for OpenOps."
  value       = aws_iam_role.openops_app.arn
}

output "instance_profile_arn" {
  description = "The ARN of the instance profile that can be attached to EC2 instances."
  value       = aws_iam_instance_profile.openops_app.arn
}

output "cur_bucket_name" {
  description = "The name of the S3 bucket used for CUR."
  value       = var.cost_usage_report ? aws_s3_bucket.cur[0].id : null
}

output "iam_user_arn" {
  description = "The ARN of the IAM user created for OpenOps."
  value       = var.create_iam_user ? aws_iam_user.openops_app[0].arn : null
}

output "iam_user_access_key_id" {
  description = "The Access Key ID of the IAM user created for OpenOps."
  value       = var.create_iam_user ? aws_iam_access_key.openops_app[0].id : null
}

output "iam_user_secret_arn" {
  description = "The ARN of the secret containing the IAM user credentials."
  value       = var.create_iam_user ? aws_secretsmanager_secret.openops_app_user[0].arn : null
}
