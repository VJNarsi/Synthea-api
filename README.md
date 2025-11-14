# AWS Batch Java Processor (Synthea)

This setup runs the Synthea Java application in AWS Batch (Fargate) that accepts parameters and uploads output to S3.

> **Note**: This project was migrated from ECS to AWS Batch. See [MIGRATION.md](MIGRATION.md) for details.

## Prerequisites

- AWS CLI configured with credentials
- Docker installed
- Python 3.7+ (for CDK)
- Node.js (for CDK CLI)

## Quick Start

### 1. One-Command Deployment

```bash
chmod +x deploy.sh
./deploy.sh
```

This script will:
- Deploy the CDK stack (VPC, Batch compute environment, job queue, job definition, ECR repo, S3 bucket, IAM roles)
- Build the Docker image (downloads synthea-with-dependencies.jar from remote URL)
- Push the image to ECR

**Custom Configuration:**
```bash
# Use a custom JAR location
JAR_URL=https://your-domain.com/path/to/synthea.jar ./deploy.sh

# Use a specific VPC instead of default
VPC_ID=vpc-xxxxx ./deploy.sh

# Use an existing S3 bucket instead of creating new one
S3_BUCKET_NAME=my-existing-bucket ./deploy.sh

# Combine multiple options
VPC_ID=vpc-xxxxx S3_BUCKET_NAME=my-bucket JAR_URL=https://example.com/synthea.jar ./deploy.sh

# Or build Docker image separately with custom URL
docker build --build-arg JAR_URL=https://your-domain.com/synthea.jar -t java-processor .
```

### 2. Submit Jobs with Parameters

Using bash:
```bash
./run-job.sh "-p 100"
```

Using Python:
```bash
python3 trigger-via-api.py -p 100
```

## Configuration

- **S3_BUCKET**: Environment variable for the output bucket
- **S3_PREFIX**: Optional prefix for S3 keys (defaults to "output")
- Java parameters are passed as command arguments

## How It Works

1. Batch job starts with your parameters
2. Java application runs: `java -jar file.jar <params>`
3. Application writes output to `/app/output`
4. Script uploads all files from `/app/output` to S3
5. Job completes

## Notes

- The JAR is downloaded automatically during Docker build from GitHub releases
- The Java app writes output files to `/app/output` directory
- Modify CPU/memory in the CDK stack (cdk/stacks/batch_java_processor_stack.py) based on your needs
