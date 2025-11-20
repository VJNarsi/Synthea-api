#!/bin/sh
# =============================================================================
# Entrypoint script for Synthea Batch container
# =============================================================================
# This script:
# 1. Runs the Synthea JAR with runtime parameters
# 2. Uploads generated output files to S3
#
# Environment Variables (set by Batch job definition):
#   S3_BUCKET - Target S3 bucket name (required)
#   S3_PREFIX - S3 key prefix for organizing files (optional, defaults to "output")
#
# Arguments:
#   All arguments are passed directly to the Java application
#   Example: -p 100 -s 12345
# =============================================================================

set -e  # Exit immediately if any command fails

echo "Starting Java application with parameters: $@"

# =============================================================================
# STEP 1: Run Synthea Java Application
# =============================================================================
# Execute the Synthea JAR with all provided command-line arguments
# The application will generate output files in /app/output directory
java -jar /app/synthea-with-dependencies.jar $@

# =============================================================================
# STEP 2: Validate S3 Configuration
# =============================================================================
# Ensure S3_BUCKET environment variable is set before attempting upload
if [ -z "$S3_BUCKET" ]; then
    echo "Error: S3_BUCKET environment variable is not set"
    exit 1
fi

# =============================================================================
# STEP 3: Upload Output Files to S3
# =============================================================================
echo "Uploading output files to S3..."

# Check if output directory contains any files
if [ "$(ls -A /app/output)" ]; then
    # Sync all files from /app/output to S3
    # Uses S3_PREFIX if set, otherwise defaults to "output"
    aws s3 sync /app/output/ "s3://${S3_BUCKET}/${S3_PREFIX:-output}/"
    echo "Upload completed successfully"
else
    echo "No output files found in /app/output"
fi
