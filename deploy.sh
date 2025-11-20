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

# Disable SSL verification for corporate proxies
export AWS_CA_BUNDLE=""
export REQUESTS_CA_BUNDLE=""
export CURL_CA_BUNDLE=""

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
# STEP 2: Upload source files to S3
# =============================================================================
echo ""
echo "Step 2: Uploading source files to S3..."

# Get build bucket name from CDK outputs
BUILD_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name BatchJavaProcessorStack \
  --query "Stacks[0].Outputs[?OutputKey=='BuildBucketName'].OutputValue" \
  --output text \
  --region $REGION)

if [ -z "$BUILD_BUCKET" ]; then
  echo "Error: Could not find build bucket name"
  exit 1
fi

echo "Build bucket: $BUILD_BUCKET"

# Create zip file with Dockerfile, entrypoint.sh, and buildspec.yml
zip -r source.zip Dockerfile entrypoint.sh buildspec.yml

# Upload to S3
aws s3 cp source.zip s3://$BUILD_BUCKET/source.zip --region $REGION

echo "Source files uploaded"

# =============================================================================
# STEP 3: Trigger CodeBuild to Build and Push Docker Image
# =============================================================================
echo ""
echo "Step 3: Triggering CodeBuild to build and push Docker image..."

# Get CodeBuild project name from CDK outputs
CODEBUILD_PROJECT=$(aws cloudformation describe-stacks \
  --stack-name BatchJavaProcessorStack \
  --query "Stacks[0].Outputs[?OutputKey=='CodeBuildProjectName'].OutputValue" \
  --output text \
  --region $REGION)

if [ -z "$CODEBUILD_PROJECT" ]; then
  echo "Error: Could not find CodeBuild project name"
  exit 1
fi

echo "Starting CodeBuild project: $CODEBUILD_PROJECT"

# Start the build
BUILD_ID=$(aws codebuild start-build \
  --project-name $CODEBUILD_PROJECT \
  --region $REGION \
  --query 'build.id' \
  --output text)

echo "Build started: $BUILD_ID"
echo "Waiting for build to complete..."

# Poll build status
while true; do
  BUILD_STATUS=$(aws codebuild batch-get-builds \
    --ids $BUILD_ID \
    --region $REGION \
    --query 'builds[0].buildStatus' \
    --output text)
  
  if [ "$BUILD_STATUS" = "SUCCEEDED" ]; then
    echo "Build completed successfully"
    break
  elif [ "$BUILD_STATUS" = "FAILED" ] || [ "$BUILD_STATUS" = "FAULT" ] || [ "$BUILD_STATUS" = "TIMED_OUT" ] || [ "$BUILD_STATUS" = "STOPPED" ]; then
    echo "Build failed with status: $BUILD_STATUS"
    exit 1
  fi
  
  echo "Build status: $BUILD_STATUS - waiting..."
  sleep 10
done

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
echo "  - CodeBuild Project: $CODEBUILD_PROJECT"
echo "  - CloudWatch Logs: /aws/batch/java-processor"
