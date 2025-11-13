#!/usr/bin/env python3
"""
CDK Application Entry Point

This is the main entry point for the CDK application.
It creates and synthesizes the CloudFormation template.

Usage:
    cdk deploy                                          - Deploy with defaults
    cdk deploy -c vpc_id=vpc-xxxxx                      - Deploy with specific VPC
    cdk deploy -c s3_bucket_name=my-bucket              - Deploy with existing S3 bucket
    cdk deploy -c vpc_id=vpc-xxxxx -c s3_bucket_name=my-bucket  - Both
    cdk synth                                           - Generate CloudFormation template
    cdk destroy                                         - Remove all resources from AWS
    
Environment Variables:
    VPC_ID          - Optional VPC ID to use instead of default VPC
    S3_BUCKET_NAME  - Optional existing S3 bucket name to use instead of creating new one
"""
import os
import aws_cdk as cdk
from stacks.ecs_java_processor_stack import EcsJavaProcessorStack

# Initialize the CDK app
app = cdk.App()

# Get configuration from context variables or environment variables
# Priority: CDK context (-c key=value) > Environment variable > Default
vpc_id = app.node.try_get_context("vpc_id") or os.environ.get("VPC_ID")
s3_bucket_name = app.node.try_get_context("s3_bucket_name") or os.environ.get("S3_BUCKET_NAME")

# Create the ECS Java Processor stack
# This will create all resources defined in EcsJavaProcessorStack
EcsJavaProcessorStack(
    app,
    "EcsJavaProcessorStack",
    vpc_id=vpc_id,
    s3_bucket_name=s3_bucket_name,
    description="ECS Fargate task for running Synthea Java application with S3 output"
)

# Synthesize the CloudFormation template
app.synth()
