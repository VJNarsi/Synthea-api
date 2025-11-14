#!/bin/bash
# =============================================================================
# One-Command Deployment Script
# =============================================================================
# This script automates the complete deployment process:
# 1. Deploys AWS infrastructure using CDK (VPC, Batch, ECR, S3, IAM)
# 2. Builds the Docker image with Synthea JAR
# 3. Pushes the image to ECR
#
# Prerequisites:
#   - AWS CLI configured with credentials
#   - Docker installed and running
#   - Python 3.7+ installed
#   - Node.js installed (for CDK CLI)
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
# =============================================================================

set -e  # Exit on any error

echo "=== AWS Batch Java Processor Deployment ==="

# =============================================================================
# Get AWS Configuration
# =============================================================================
# Retrieve AWS account ID and region for resource naming and deployment
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
REGION=${REGION:-us-east-1}  # Default to us-east-1 if not configured

echo "Account: $ACCOUNT_ID"
echo "Region: $REGION"

# =============================================================================
# STEP 1: Deploy CDK Infrastructure Stack
# =============================================================================
# Creates: Batch compute environment, job queue, job definition, ECR repository, S3 bucket, IAM roles, security groups
echo ""
echo "Step 1: Deploying CDK stack..."
cd cdk

# Create Python virtual environment for CDK dependencies
python3 -m venv .venv
source .venv/bin/activate

# Install CDK Python libraries
pip install -r requirements.txt

# Bootstrap CDK (one-time setup per account/region)
# Creates S3 bucket and IAM roles for CDK deployments
cdk bootstrap aws://$ACCOUNT_ID/$REGION

# Deploy the stack without manual approval prompts
# Optional: Specify VPC_ID and/or S3_BUCKET_NAME environment variables
# Examples:
#   VPC_ID=vpc-xxxxx ./deploy.sh
#   S3_BUCKET_NAME=my-bucket ./deploy.sh
#   VPC_ID=vpc-xxxxx S3_BUCKET_NAME=my-bucket ./deploy.sh

CDK_ARGS="--require-approval never"

if [ -n "$VPC_ID" ]; then
    echo "Using VPC: $VPC_ID"
    CDK_ARGS="$CDK_ARGS -c vpc_id=$VPC_ID"
else
    echo "Using default VPC"
fi

if [ -n "$S3_BUCKET_NAME" ]; then
    echo "Using existing S3 bucket: $S3_BUCKET_NAME"
    CDK_ARGS="$CDK_ARGS -c s3_bucket_name=$S3_BUCKET_NAME"
else
    echo "Will create new S3 bucket: synthea-output-$ACCOUNT_ID"
fi

cdk deploy $CDK_ARGS

cd ..

# =============================================================================
# STEP 2: Build Docker Image
# =============================================================================
# Packages the Synthea JAR, entrypoint script, and dependencies into a container
# The JAR is downloaded from a remote URL during the build process
echo ""
echo "Step 2: Building Docker image..."

# Optional: Set custom JAR URL via environment variable
# Default: Downloads from Synthea's GitHub releases
JAR_URL=${JAR_URL:-https://github.com/synthetichealth/synthea/releases/download/master-branch-latest/synthea-with-dependencies.jar}

echo "JAR will be downloaded from: $JAR_URL"
docker build --build-arg JAR_URL="$JAR_URL" -t java-processor .

# =============================================================================
# STEP 3: Push Image to ECR
# =============================================================================
# Uploads the Docker image to AWS Elastic Container Registry
echo "Step 3: Pushing to ECR..."

# Authenticate Docker with ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Tag image with ECR repository URL
docker tag java-processor:latest \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/java-processor:latest

# Push to ECR
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/java-processor:latest

# =============================================================================
# Deployment Complete
# =============================================================================
echo ""
echo "=== Deployment Complete ==="
echo ""
echo "To submit a job with parameters:"
echo "  ./run-job.sh \"-p 100\""
echo ""
echo "Or use Python:"
echo "  python3 trigger-via-api.py -p 100"
echo ""
echo "Resources created:"
echo "  - Batch Job Queue: java-processor-queue"
echo "  - Batch Job Definition: java-processor-job"
if [ -n "$S3_BUCKET_NAME" ]; then
    echo "  - S3 Bucket: $S3_BUCKET_NAME (existing)"
else
    echo "  - S3 Bucket: synthea-output-$ACCOUNT_ID (new)"
fi
echo "  - ECR Repository: java-processor"
echo "  - CloudWatch Logs: /aws/batch/java-processor"
