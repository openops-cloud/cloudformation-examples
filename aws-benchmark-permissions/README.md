# AWS Benchmark Permissions CloudFormation Template

This CloudFormation template creates an IAM role with the necessary permissions for the OpenOps AWS Benchmark feature.

## Overview

The template creates:
- **IAM Role**: `OpenOpsBenchmarkRole` - A cross-account assumable role
- **3 Managed Policies**:
  1. `OpenOps-ComputeOptimizer-ReadOnly` - Access to AWS Compute Optimizer recommendations
  2. `OpenOps-Resources-ReadOnly` - Read-only access to AWS resources (EC2, RDS, ELB, DynamoDB, CloudWatch, Cost Explorer, CloudTrail, etc.)
  3. `OpenOps-Pricing-ReadOnly` - Access to AWS Pricing API

## Permissions Included

### Compute Optimizer
- Get EC2, EBS, RDS, Lambda, ECS, Auto Scaling Group, Idle, and License recommendations
- Get RDS database recommendations and enrollment status

### Resource Read Access
- **EC2**: Describe instances, volumes, snapshots, instance types, NAT gateways, VPC endpoints, elastic IPs, regions
- **RDS**: Describe database instances, snapshots, and engine versions
- **ELB**: Describe load balancers
- **DynamoDB**: List and describe tables
- **CloudWatch**: Get metric statistics for resource utilization
- **Cost Explorer**: Get cost and usage data
- **CloudTrail**: Lookup events for resource tracking
- **Organizations**: Get account information
- **Tagging**: Get resource tags

### Pricing API
- Describe services, get attribute values, and get product pricing

**Note**: Lambda, ECS, and Auto Scaling recommendations are retrieved through the Compute Optimizer API, not through direct service APIs.

## Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `TrustedAccountId` | AWS Account ID that will assume this role | Yes | - |
| `ExternalId` | External ID for secure cross-account access | No | (empty) |

## Deployment

### Using AWS Console

1. Navigate to CloudFormation in AWS Console
2. Click "Create stack" → "With new resources"
3. Upload this template file
4. Provide parameters:
   - `TrustedAccountId`: Your OpenOps AWS account ID or your own account ID
   - `ExternalId`: (Optional but recommended) A unique identifier for security
5. Review and create the stack

### Using AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name openops-benchmark-permissions \
  --template-body file://template.yml \
  --parameters \
    ParameterKey=TrustedAccountId,ParameterValue=123456789012 \
    ParameterKey=ExternalId,ParameterValue=your-unique-external-id \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### Get Stack Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name openops-benchmark-permissions \
  --query 'Stacks[0].Outputs' \
  --region us-east-1
```

## Usage with OpenOps

After deploying the stack:

1. **Get the Role ARN** from the CloudFormation outputs
2. **In OpenOps**:
   - Go to Settings → Connections
   - Create or edit an AWS connection
   - Configure it to assume the role:
     - Role ARN: `arn:aws:iam::ACCOUNT_ID:role/OpenOpsBenchmarkRole`
     - External ID: (the value you provided during deployment)
3. **Run Benchmark**:
   - Navigate to the Benchmark section
   - Select your AWS connection
   - Run the benchmark workflows

## Security Considerations

### External ID
An External ID is highly recommended when allowing cross-account access. It prevents the "confused deputy problem" where an attacker could trick a trusted account into accessing your resources.

### Least Privilege
This template follows the principle of least privilege by:
- Providing only read-only access to resources
- No write, modify, or delete permissions (except for Compute Optimizer reads)
- Scoped to only the services needed for benchmarking

### Multi-Account Setup
For AWS Organizations with multiple accounts:
1. Deploy this stack in your management account or each member account
2. Use the same External ID across all accounts
3. Configure OpenOps to assume roles in different accounts

## Updating the Template

To update the permissions:

```bash
aws cloudformation update-stack \
  --stack-name openops-benchmark-permissions \
  --template-body file://template.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

## Cleanup

To remove the stack and all created resources:

```bash
aws cloudformation delete-stack \
  --stack-name openops-benchmark-permissions \
  --region us-east-1
```

## Troubleshooting

### "User is not authorized to perform: iam:CreateRole"
- Ensure you have permissions to create IAM roles
- Add `--capabilities CAPABILITY_NAMED_IAM` to the CLI command

### "Role cannot be assumed"
- Verify the `TrustedAccountId` is correct
- Check that the External ID matches in both the role and OpenOps configuration
- Ensure the trust policy allows the correct principal

### "Access Denied" when running benchmarks
- Verify all necessary permissions are in the policies
- Check if service control policies (SCPs) in AWS Organizations are blocking access
- Ensure Compute Optimizer is enabled in your AWS account

## Related Resources

- [AWS Compute Optimizer Documentation](https://docs.aws.amazon.com/compute-optimizer/)
- [IAM Cross-Account Access](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_common-scenarios_third-party.html)
- [OpenOps Documentation](https://docs.openops.com)
