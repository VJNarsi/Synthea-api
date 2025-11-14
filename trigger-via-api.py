#!/usr/bin/env python3
"""
AWS Batch Job Submission Script

This script programmatically submits an AWS Batch job with runtime parameters.
It passes parameters to the Synthea container running in AWS Batch.

Usage:
    python3 trigger-via-api.py -p 100
    python3 trigger-via-api.py -p 1000 -s 12345

Requirements:
    - boto3 (pip install boto3)
    - AWS credentials configured (aws configure)
    - Batch job queue and job definition deployed
"""
import boto3
import sys
import time


def submit_batch_job(params):
    """
    Submit an AWS Batch job with runtime parameters.
    
    Args:
        params (list): Command-line parameters to pass to the Java application
        
    Returns:
        dict: Batch submit_job API response containing job details
        
    Note:
        - Parameters are passed via containerOverrides.command
        - This allows different parameters for each job execution
        - Job runs asynchronously; use Batch console to monitor progress
    """
    batch = boto3.client('batch')
    
    # Generate a unique job name with timestamp
    job_name = f"synthea-job-{int(time.time())}"
    
    # Submit the job to AWS Batch
    response = batch.submit_job(
        jobName=job_name,
        jobQueue='java-processor-queue',  # Must match CDK stack job queue name
        jobDefinition='java-processor-job',  # Must match CDK stack job definition
        containerOverrides={
            'command': params  # Runtime parameters passed to entrypoint.sh
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
    
    # Submit the Batch job
    print(f"Submitting Batch job with parameters: {params}")
    response = submit_batch_job(params)
    
    # Extract and display the job ID
    job_id = response['jobId']
    job_name = response['jobName']
    print(f"Job submitted: {job_name}")
    print(f"Job ID: {job_id}")
    print("\nMonitor job progress:")
    print("  - AWS Console: Batch > Jobs > java-processor-queue")
    print("  - CloudWatch Logs: /aws/batch/java-processor")
    print("  - S3 Output: Check your synthea-output-* bucket")
    print(f"\nCheck job status:")
    print(f"  aws batch describe-jobs --jobs {job_id}")
