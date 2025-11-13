#!/bin/bash
# =============================================================================
# ECS Task Runner Script
# =============================================================================
# This script triggers an ECS Fargate task with runtime parameters.
# It automatically discovers VPC configuration and launches the task.
#
# Usage:
#   ./run-task.sh "-p 100"
#   ./run-task.sh "-p 1000 -s 12345"
#
# Requirements:
#   - AWS CLI configured with credentials
#   - ECS cluster and task definition deployed via CDK
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# Configuration
# =============================================================================
# Get AWS region from CLI config, default to us-east-1
REGION=$(aws configure get region)
REGION=${REGION:-us-east-1}

# These names must match the CDK stack configuration
CLUSTER_NAME="java-processor-cluster"
TASK_DEFINITION="java-processor-task"

# =============================================================================
# Discover VPC Configuration
# =============================================================================
# Find the default VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region $REGION)

# Get the first available subnet in the VPC
SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[0].SubnetId" \
  --output text \
  --region $REGION)

# Find the security group created by CDK (contains 'TaskSecurityGroup' in name)
SECURITY_GROUP=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*TaskSecurityGroup*" "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --region $REGION)

# =============================================================================
# Validate Input Parameters
# =============================================================================
# All script arguments are passed to the Java application
JAVA_PARAMS="$@"

if [ -z "$JAVA_PARAMS" ]; then
    echo "Error: No parameters provided"
    echo ""
    echo "Usage: ./run-task.sh <java-parameters>"
    echo "Example: ./run-task.sh \"-p 100\""
    echo ""
    echo "Common Synthea parameters:"
    echo "  -p <number>  : Generate <number> patients"
    echo "  -s <seed>    : Random seed for reproducibility"
    echo "  -g <gender>  : Generate only M or F patients"
    exit 1
fi

echo "Running ECS task with parameters: $JAVA_PARAMS"

# =============================================================================
# Launch ECS Task
# =============================================================================
# Run the task on Fargate with the provided parameters
# The task runs asynchronously; use AWS Console to monitor progress
TASK_ARN=$(aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --task-definition "$TASK_DEFINITION" \
  --launch-type FARGATE \
  --region $REGION \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"java-processor\",\"command\":[\"$JAVA_PARAMS\"]}]}" \
  --query "tasks[0].taskArn" \
  --output text)

echo "Task started: $TASK_ARN"
echo ""
echo "Monitor task progress:"
echo "  - AWS Console: ECS > Clusters > $CLUSTER_NAME"
echo "  - CloudWatch Logs: /ecs/java-processor"
echo "  - S3 Output: Check your synthea-output-* bucket"
