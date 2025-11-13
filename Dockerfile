# =============================================================================
# Dockerfile for Synthea Java Application on ECS Fargate
# =============================================================================
# This container runs the Synthea patient data generator and uploads
# output files to S3.
#
# Build: docker build -t java-processor .
# Run:   docker run java-processor -p 100
# =============================================================================

# Use Amazon Corretto 17 (AWS-optimized OpenJDK distribution)
# Alpine variant for smaller image size
FROM amazoncorretto:17-alpine

# Install AWS CLI for S3 operations
# Required for uploading generated files to S3
RUN apk add --no-cache aws-cli

# Set working directory for the application
WORKDIR /app

# Copy the Synthea JAR file into the container
# Ensure synthea-with-dependencies.jar is in the same directory as this Dockerfile
COPY synthea-with-dependencies.jar /app/synthea-with-dependencies.jar

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
