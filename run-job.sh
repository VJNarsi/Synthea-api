#!/bin/bash
# =============================================================================
# AWS Batch Job Submission Script
# =============================================================================
# This script submits an AWS Batch job with runtime parameters.
# It automatically discovers the job queue and definition from the CDK stack.
#
# Usage:
#   ./run-job.sh "-p 100"
#   ./run-job.sh "-p 1000 -s 12345"
#
# Requirements:
#   - AWS CLI configured with credentials
#   - Batch job queue and job definition deployed via CDK
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# Configuration
# =============================================================================
# Get AWS region from CLI config, default to us-east-1
REGION=$(aws configure get region)
REGION=${REGION:-us-east-1}

# These names must match the CDK stack configuration
JOB_QUEUE="java-processor-queue"
JOB_DEFINITION="java-processor-job"

# =============================================================================
# Validate Input Parameters
# =============================================================================
# All script arguments are passed to the Java application
JAVA_PARAMS="$@"

if [ -z "$JAVA_PARAMS" ]; then
    echo "Error: No parameters provided"
    echo ""
    echo "Usage: ./run-job.sh <java-parameters>"
    echo "Example: ./run-job.sh \"-p 100\""
    echo ""
    echo "Common Synthea parameters:"
    echo "  -p <number>  : Generate <number> patients"
    echo "  -s <seed>    : Random seed for reproducibility"
    echo "  -g <gender>  : Generate only M or F patients"
    exit 1
fi

echo "Submitting Batch job with parameters: $JAVA_PARAMS"

# =============================================================================
# Submit Batch Job
# =============================================================================
# Submit the job to AWS Batch with the provided parameters
# The job runs asynchronously; use AWS Console to monitor progress
JOB_ID=$(aws batch submit-job \
  --job-name "synthea-job-$(date +%s)" \
  --job-queue "$JOB_QUEUE" \
  --job-definition "$JOB_DEFINITION" \
  --region $REGION \
  --container-overrides "{\"command\":[\"$JAVA_PARAMS\"]}" \
  --query "jobId" \
  --output text)

echo "Job submitted: $JOB_ID"
echo ""
echo "Monitor job progress:"
echo "  - AWS Console: Batch > Jobs > $JOB_QUEUE"
echo "  - CloudWatch Logs: /aws/batch/java-processor"
echo "  - S3 Output: Check your synthea-output-* bucket"
echo ""
echo "Check job status:"
echo "  aws batch describe-jobs --jobs $JOB_ID --region $REGION"
