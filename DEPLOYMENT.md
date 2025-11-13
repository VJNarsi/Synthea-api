# Deployment Guide

## Configuration Options

This deployment supports multiple configuration options that can be customized.

## VPC Configuration

You can deploy this stack to use either the default VPC or a specific VPC.

### Option 1: Use Default VPC (Simplest)

```bash
./deploy.sh
```

### Option 2: Use Specific VPC via Environment Variable

```bash
VPC_ID=vpc-0123456789abcdef0 ./deploy.sh
```

### Option 3: Use Specific VPC via CDK Context

```bash
cd cdk
cdk deploy -c vpc_id=vpc-0123456789abcdef0
```

## S3 Bucket Configuration

You can use an existing S3 bucket or let the stack create a new one.

### Option 1: Create New Bucket (Default)

```bash
./deploy.sh
```
Creates: `synthea-output-{account-id}`

### Option 2: Use Existing Bucket via Environment Variable

```bash
S3_BUCKET_NAME=my-existing-bucket ./deploy.sh
```

**Important:** When using an existing bucket:
- The bucket must already exist
- The bucket must be in the same region as your deployment
- The CDK stack will grant the ECS task role read/write permissions to this bucket

### Option 3: Use Existing Bucket via CDK Context

```bash
cd cdk
cdk deploy -c s3_bucket_name=my-existing-bucket
```

## Custom JAR URL

By default, the Docker image downloads Synthea from GitHub. To use a custom JAR:

```bash
JAR_URL=https://your-domain.com/path/to/synthea.jar ./deploy.sh
```

## Combined Configuration

You can combine multiple options:

```bash
VPC_ID=vpc-xxxxx S3_BUCKET_NAME=my-bucket JAR_URL=https://example.com/synthea.jar ./deploy.sh
```

## Context File Configuration (Recommended for Teams)

Create `cdk/cdk.context.json`:
```json
{
  "vpc_id": "vpc-0123456789abcdef0",
  "s3_bucket_name": "my-existing-bucket"
}
```

Then deploy:
```bash
./deploy.sh
```

This approach is best for:
- Team environments with shared configuration
- CI/CD pipelines
- Consistent deployments across environments

## VPC Requirements

Your VPC must have:
- At least one subnet with internet access (for Fargate tasks)
- NAT Gateway or public subnet (for pulling ECR images and accessing S3)
- DNS resolution enabled
- DNS hostnames enabled

## Troubleshooting

### Task fails to start
- Check that your VPC has internet connectivity
- Verify security group allows outbound traffic
- Ensure subnets have available IP addresses

### Cannot pull ECR image
- Verify VPC has route to internet (NAT Gateway or Internet Gateway)
- Check VPC endpoints for ECR if using private subnets

### Cannot upload to S3
- Verify task role has S3 permissions
- Check VPC has route to S3 (internet or S3 VPC endpoint)
