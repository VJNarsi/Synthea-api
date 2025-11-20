# =============================================================================
# Dockerfile for Synthea Java Application on AWS Batch
# =============================================================================
# This container runs the Synthea patient data generator and uploads
# output files to S3.
#
# Build: docker build -t java-processor .
# Run:   docker run java-processor -p 100
# =============================================================================

# Use Amazon Corretto 17 from AWS ECR Public (no rate limits)
FROM public.ecr.aws/amazoncorretto/amazoncorretto:17-al2023

# Install AWS CLI and curl for S3 operations and downloading JAR
RUN yum install -y aws-cli unzip && yum clean all

# Set working directory for the application
WORKDIR /app

# Download the Synthea JAR file from remote URL
# Set JAR_URL as a build argument to specify the download location
# Example: docker build --build-arg JAR_URL=https://example.com/synthea.jar -t java-processor .
ARG JAR_URL=https://github.com/synthetichealth/synthea/releases/download/master-branch-latest/synthea-with-dependencies.jar
RUN curl -L -o /app/synthea-with-dependencies.jar "$JAR_URL"

# Create output directory where Synthea will write generated files
# This directory is synced to S3 after processing
RUN mkdir -p /app/output

# Copy and configure the entrypoint script
# This script runs Synthea and handles S3 upload
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Set the entrypoint to our custom script
# All docker run arguments are passed to this script
ENTRYPOINT ["/app/entrypoint.sh"]
