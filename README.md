# CloudFormation Examples

A collection of AWS CloudFormation templates for practice and testing purposes. This repository contains various infrastructure-as-code examples that can be used by the OpenOps platform for validation, testing, and remediation scenarios.

## Repository Structure

Each example is contained in its own folder with:
- CloudFormation template (YAML format)
- README with description and usage instructions

## Examples

### S3 Bucket with Standard Configuration

Location: `s3-bucket-standard-tiering/`

Creates an S3 bucket with standard configuration and security best practices.

## Usage

To deploy any example stack:

```bash
aws cloudformation create-stack \
  --stack-name <stack-name> \
  --template-body file://<path-to-template.yml> \
  --region <aws-region>
```

To delete a stack:

```bash
aws cloudformation delete-stack \
  --stack-name <stack-name> \
  --region <aws-region>
```

## Contributing

When adding new examples:
1. Create a descriptive folder name
2. Include a CloudFormation template in YAML format
3. Add a README.md explaining the template's purpose
4. Update this main README with a reference to the new example
