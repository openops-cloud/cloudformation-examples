# OpenOps App IAM Role — Terraform

Terraform equivalent of the [OpenOpsApp CloudFormation role stack](https://openops.s3.us-east-2.amazonaws.com/OpenOpsAppRoleStack.yml). It creates the IAM role and permissions used by the OpenOps app to connect to your AWS account and run workflows from the OpenOps template catalog.

**What it creates:**

- An IAM role (default name `OpenOpsApp`) that can be assumed by the AWS account where OpenOps runs, and an instance profile for attaching the role to EC2 instances
- A read-access managed policy that lets the role know basic information about resources, without access to secrets
- Optional (enabled by default, can be disabled via variables):
  - Write permissions for optimization actions — tagging, EC2 instances, EBS volumes, RDS, CloudFormation stacks, CloudFront
  - Cost Optimization Hub / Compute Optimizer enrollment permissions
  - A Cost and Usage Report (CUR) exported to a new S3 bucket (`openops-cur-<account-id>`)
- Optional (disabled by default): an IAM user with the same permissions as the role, with its access key stored in AWS Secrets Manager

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- AWS credentials with permissions to create IAM, S3, CUR, and (if enabling the IAM user) Secrets Manager resources
- **Region:** apply in `us-east-1` when `cost_usage_report` is enabled — CUR report definitions are only available in that region

## Usage

```bash
terraform init
terraform plan -var aws_account_id=<OpenOps environment AWS account ID>
terraform apply -var aws_account_id=<OpenOps environment AWS account ID>
```

`aws_account_id` is the 12-digit ID of the AWS account where your OpenOps environment is deployed — the account that will assume the role.

After applying, use the `iam_role_arn` output to create an AWS connection in OpenOps (assume-role authentication).

To disable a permission set, set its variable to `false`, e.g.:

```bash
terraform apply \
  -var aws_account_id=123456789012 \
  -var rds_optimization_access=false \
  -var cost_usage_report=false
```

### Multi-account rollout

To create the role in many accounts, consume this directory as a module (one instance per provider/account alias):

```hcl
module "openops_role" {
  source = "github.com/openops-cloud/cloudformation-examples//openops-app-role-aws/terraform"

  aws_account_id = "123456789012"
  external_id    = var.openops_external_id

  providers = {
    aws = aws.member_account
  }
}
```

## Variables

| Name | Description | Default |
| --- | --- | --- |
| `aws_account_id` | AWS account ID allowed to assume the OpenOps role (12 digits) | — (required) |
| `external_id` | Optional external ID required to assume the role | `""` |
| `role_name` | Name of the IAM role and instance profile | `"OpenOpsApp"` |
| `cost_usage_report` | Create the Cost and Usage Report and its S3 bucket | `true` |
| `optimization_hub_configuration_access` | Allow enrolling the account to the Cost Optimization Hub | `true` |
| `tagging_access` | Allow adding, updating and removing resource tags | `true` |
| `ec2_instance_optimization_access` | Allow optimizing EC2 instances (stop/terminate/modify) | `true` |
| `volume_optimization_access` | Allow optimizing EBS volumes (delete unattached, gp2→gp3) | `true` |
| `rds_optimization_access` | Allow optimizing RDS instances (stop/terminate/modify) | `true` |
| `stack_optimization_access` | Allow optimizing resources via CloudFormation stack updates | `true` |
| `cloudfront_optimization_access` | Allow optimizing CloudFront distributions | `true` |
| `create_iam_user` | Create an IAM user with the same permissions as the role | `false` |

## Outputs

| Name | Description |
| --- | --- |
| `iam_role_arn` | ARN of the IAM role — use this to create the AWS connection in OpenOps |
| `instance_profile_arn` | ARN of the instance profile for EC2 instances |
| `cur_bucket_name` | Name of the CUR S3 bucket (`null` when CUR is disabled) |
| `iam_user_arn` | ARN of the IAM user (`null` unless `create_iam_user`) |
| `iam_user_access_key_id` | Access key ID of the IAM user (`null` unless `create_iam_user`) |
| `iam_user_secret_arn` | ARN of the Secrets Manager secret holding the user credentials (`null` unless `create_iam_user`) |

## Differences from the CloudFormation template

- `external_id` — the CloudFormation template does not currently support an external ID; here it's an optional variable that adds an `sts:ExternalId` condition to the role's trust policy.
- `role_name` — the CloudFormation template hardcodes the `OpenOpsApp` name; here it's configurable (the managed policy names are derived from it).

## Cleanup

```bash
terraform destroy -var aws_account_id=<OpenOps environment AWS account ID>
```

If the CUR bucket already received report objects, empty it first (`aws s3 rm s3://openops-cur-<account-id> --recursive`), as Terraform will not delete a non-empty bucket.
