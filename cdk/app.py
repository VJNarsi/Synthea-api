#!/usr/bin/env python3
"""
CDK Application Entry Point

This is the main entry point for the CDK application.
It creates and synthesizes the CloudFormation template.

Usage:
    cdk deploy    - Deploy the stack to AWS
    cdk synth     - Generate CloudFormation template
    cdk destroy   - Remove all resources from AWS
"""
import aws_cdk as cdk
from stacks.ecs_java_processor_stack import EcsJavaProcessorStack

# Initialize the CDK app
app = cdk.App()

# Create the ECS Java Processor stack
# This will create all resources defined in EcsJavaProcessorStack
EcsJavaProcessorStack(
    app, 
    "EcsJavaProcessorStack",
    description="ECS Fargate task for running Synthea Java application with S3 output"
)

# Synthesize the CloudFormation template
app.synth()
