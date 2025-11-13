# ECS Java Processor (Synthea)

This setup runs the Synthea Java application in ECS Fargate that accepts parameters and uploads output to S3.

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
- Deploy the CDK stack (VPC, ECS cluster, ECR repo, S3 bucket, IAM roles)
- Build the Docker image with synthea-with-dependencies.jar
- Push the image to ECR

### 2. Run Tasks with Parameters

Using bash:
```bash
./run-task.sh "-p 100"
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

1. ECS task starts with your parameters
2. Java application runs: `java -jar file.jar <params>`
3. Application writes output to `/app/output`
4. Script uploads all files from `/app/output` to S3
5. Task completes

## Notes

- The `synthea-with-dependencies.jar` should be in the same directory as the Dockerfile before building
- The Java app should write output files to `/app/output` directory
- Modify CPU/memory in task-definition.json based on your needs
