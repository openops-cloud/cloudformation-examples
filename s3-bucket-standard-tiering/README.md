# S3 Bucket with Standard Configuration

This CloudFormation template creates an Amazon S3 bucket with standard configuration and security best practices.

## Features

- **Versioning**: Enabled for data protection
- **Encryption**: Server-side encryption with AES-256
- **Public Access Block**: All public access is blocked by default
- **Tagging**: Pre-configured tags for management

## Parameters

- **BucketName** (Optional): Custom name for the S3 bucket. If not provided, AWS will auto-generate a unique name.

## Outputs

- **BucketName**: The name of the created S3 bucket
- **BucketArn**: The ARN of the created S3 bucket

## Deployment

### Using AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name my-s3-bucket-stack \
  --template-body file://template.yml \
  --region us-east-1
```

### With Custom Bucket Name

```bash
aws cloudformation create-stack \
  --stack-name my-s3-bucket-stack \
  --template-body file://template.yml \
  --parameters ParameterKey=BucketName,ParameterValue=my-unique-bucket-name \
  --region us-east-1
```

## Cleanup

To delete the stack and all resources:

```bash
# First, empty the bucket if it contains objects
aws s3 rm s3://<bucket-name> --recursive

# Then delete the stack
aws cloudformation delete-stack \
  --stack-name my-s3-bucket-stack \
  --region us-east-1
```


