# E-GEDSH CloudFormation Deployment

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured (for CLI deployment)
- GitHub OIDC provider configured in IAM (see below)

## Setup GitHub OIDC Provider

Before deploying the stack, configure the GitHub OIDC provider:

### AWS Console
1. Go to IAM → Identity providers → Add provider
2. Select "OpenID Connect"
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`
5. Click "Add provider"

### AWS CLI
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

## Deploy via AWS CLI

### Basic Deployment
```bash
aws cloudformation create-stack \
  --stack-name e-gedsh-stack \
  --template-body file://cloudformation.yml \
  --capabilities CAPABILITY_NAMED_IAM
```

### With Custom Parameters
```bash
aws cloudformation create-stack \
  --stack-name e-gedsh-stack \
  --template-body file://cloudformation.yml \
  --parameters \
    ParameterKey=BucketName,ParameterValue=my-custom-bucket \
    ParameterKey=ApplicationName,ParameterValue=E-Gedsh \
    ParameterKey=GitHubOrg,ParameterValue=srophe \
    ParameterKey=GitHubCodeRepo,ParameterValue=e-gedsh-app \
    ParameterKey=GitHubDataRepo,ParameterValue=e-gedsh \
  --capabilities CAPABILITY_NAMED_IAM
```

### Update Stack
```bash
aws cloudformation update-stack \
  --stack-name e-gedsh-stack \
  --template-body file://cloudformation.yml \
  --capabilities CAPABILITY_NAMED_IAM
```

### Delete Stack
```bash
# Empty S3 bucket first
aws s3 rm s3://gaddel-e-gedsh-site --recursive

# Delete stack
aws cloudformation delete-stack --stack-name e-gedsh-stack
```

## Deploy via AWS Console

1. Go to CloudFormation → Create stack → With new resources
2. Choose "Upload a template file"
3. Upload `cloudformation.yml`
4. Click "Next"
5. Enter stack name: `e-gedsh-stack`
6. Configure parameters (or use defaults):
   - BucketName: `gaddel-e-gedsh-site`
   - ApplicationName: `E-Gedsh`
   - GitHubOrg: `srophe`
   - GitHubCodeRepo: `e-gedsh-app`
   - GitHubDataRepo: `e-gedsh`
7. Click "Next"
8. Check "I acknowledge that AWS CloudFormation might create IAM resources with custom names"
9. Click "Submit"

## Stack Outputs

After deployment, retrieve outputs:

### AWS CLI
```bash
aws cloudformation describe-stacks \
  --stack-name e-gedsh-stack \
  --query 'Stacks[0].Outputs'
```

### Outputs Include
- **EGedshS3Bucket**: S3 bucket name
- **EGedshCloudFrontURL**: CloudFront distribution URL
- **DeployRoleArn**: IAM role ARN for GitHub Actions

## GitHub Actions Configuration

Add the `DeployRoleArn` output to your GitHub repository secrets:
1. Go to repository Settings → Secrets and variables → Actions
2. Add secret: `AWS_ROLE_ARN` with the value from stack outputs
3. Add secret: `AWS_REGION` with your AWS region (e.g., `us-east-1`)

## Monitoring

### Check Stack Status
```bash
aws cloudformation describe-stacks \
  --stack-name e-gedsh-stack \
  --query 'Stacks[0].StackStatus'
```

### View Stack Events
```bash
aws cloudformation describe-stack-events \
  --stack-name e-gedsh-stack \
  --max-items 10
```
