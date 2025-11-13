#!/usr/bin/env python3
"""
ECS Task Trigger Script

This script programmatically triggers an ECS Fargate task with runtime parameters.
It automatically discovers VPC configuration and passes parameters to the Synthea container.

Usage:
    python3 trigger-via-api.py -p 100
    python3 trigger-via-api.py -p 1000 -s 12345

Requirements:
    - boto3 (pip install boto3)
    - AWS credentials configured (aws configure)
    - ECS cluster and task definition deployed
"""
import boto3
import sys


def get_vpc_config():
    """
    Discover VPC configuration from the default VPC.
    
    Returns:
        tuple: (subnet_id, security_group_id)
        
    Note:
        - Uses the first available subnet in the default VPC
        - Looks for security group with 'TaskSecurityGroup' in the name
        - Modify this function if using a custom VPC
    """
    ec2 = boto3.client('ec2')
    
    # Find the default VPC
    vpcs = ec2.describe_vpcs(Filters=[{'Name': 'isDefault', 'Values': ['true']}])
    vpc_id = vpcs['Vpcs'][0]['VpcId']
    
    # Get the first subnet in the VPC
    # For production, consider selecting specific availability zones
    subnets = ec2.describe_subnets(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    subnet_id = subnets['Subnets'][0]['SubnetId']
    
    # Find the security group created by CDK stack
    # The security group name contains 'TaskSecurityGroup'
    sgs = ec2.describe_security_groups(
        Filters=[
            {'Name': 'group-name', 'Values': ['*TaskSecurityGroup*']},
            {'Name': 'vpc-id', 'Values': [vpc_id]}
        ]
    )
    sg_id = sgs['SecurityGroups'][0]['GroupId']
    
    return subnet_id, sg_id


def run_ecs_task(params):
    """
    Trigger an ECS Fargate task with runtime parameters.
    
    Args:
        params (list): Command-line parameters to pass to the Java application
        
    Returns:
        dict: ECS run_task API response containing task details
        
    Note:
        - Parameters are passed via containerOverrides.command
        - This allows different parameters for each task execution
        - Task runs asynchronously; use ECS console to monitor progress
    """
    ecs = boto3.client('ecs')
    subnet_id, sg_id = get_vpc_config()
    
    # Launch the ECS task with Fargate
    response = ecs.run_task(
        cluster='java-processor-cluster',  # Must match CDK stack cluster name
        taskDefinition='java-processor-task',  # Must match CDK stack task definition
        launchType='FARGATE',  # Serverless compute
        networkConfiguration={
            'awsvpcConfiguration': {
                'subnets': [subnet_id],  # Where to run the task
                'securityGroups': [sg_id],  # Network access rules
                'assignPublicIp': 'ENABLED'  # Required for ECR and S3 access
            }
        },
        overrides={
            'containerOverrides': [
                {
                    'name': 'java-processor',  # Must match container name in task definition
                    'command': params  # Runtime parameters passed to entrypoint.sh
                }
            ]
        }
    )
    
    return response


if __name__ == '__main__':
    # Parse command-line arguments
    # All arguments are passed directly to the Synthea JAR
    params = sys.argv[1:]
    
    # Validate that parameters were provided
    if not params:
        print("Usage: ./trigger-via-api.py param1 param2 param3")
        print("Example: ./trigger-via-api.py -p 100")
        print("\nCommon Synthea parameters:")
        print("  -p <number>  : Generate <number> patients")
        print("  -s <seed>    : Random seed for reproducibility")
        print("  -g <gender>  : Generate only M or F patients")
        sys.exit(1)
    
    # Trigger the ECS task
    print(f"Triggering ECS task with parameters: {params}")
    response = run_ecs_task(params)
    
    # Extract and display the task ARN
    task_arn = response['tasks'][0]['taskArn']
    print(f"Task started: {task_arn}")
    print("\nMonitor task progress:")
    print("  - AWS Console: ECS > Clusters > java-processor-cluster")
    print("  - CloudWatch Logs: /ecs/java-processor")
    print("  - S3 Output: Check your synthea-output-* bucket")
