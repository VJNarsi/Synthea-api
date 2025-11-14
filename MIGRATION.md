# Migration from ECS to AWS Batch

This project has been migrated from ECS Fargate to AWS Batch (using Fargate compute).

## Key Changes

### Infrastructure
- **ECS Cluster** → **AWS Batch Compute Environment**
- **ECS Task Definition** → **AWS Batch Job Definition**
- **ECS Task** → **AWS Batch Job**
- **Task Role** → **Job Role**

### Scripts
- `run-task.sh` → `run-job.sh`
- `trigger-via-api.py` updated to use `batch.submit_job()` instead of `ecs.run_task()`

### CloudWatch Logs
- Log group changed from `/ecs/java-processor` to `/aws/batch/java-processor`

### CDK Stack
- Stack renamed from `EcsJavaProcessorStack` to `BatchJavaProcessorStack`
- File renamed from `ecs_java_processor_stack.py` to `batch_java_processor_stack.py`

## Benefits of AWS Batch

1. **Better for batch workloads**: AWS Batch is purpose-built for batch processing jobs
2. **Job scheduling**: Built-in job queue management and prioritization
3. **Job dependencies**: Can create job dependencies (not used in this simple setup)
4. **Automatic retries**: Built-in retry logic for failed jobs
5. **Cost optimization**: Better suited for sporadic, compute-intensive workloads

## Legacy Files

The following files are no longer used but kept for reference:
- `task-definition.json` - ECS task definition (now defined in CDK)
- `iam-task-role-policy.json` - IAM policy (now managed by CDK)
- `trust-policy.json` - Trust policy (now managed by CDK)

All infrastructure is now defined in the CDK stack at `cdk/stacks/batch_java_processor_stack.py`.

## Deployment

The deployment process remains the same:

```bash
./deploy.sh
```

## Running Jobs

Submit jobs using the new script:

```bash
./run-job.sh "-p 100"
```

Or using Python:

```bash
python3 trigger-via-api.py -p 100
```

## Monitoring

- **AWS Console**: Batch > Jobs > java-processor-queue
- **CloudWatch Logs**: /aws/batch/java-processor
- **S3 Output**: synthea-output-{account-id} bucket
