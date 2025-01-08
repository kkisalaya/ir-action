#!/bin/sh

set -e

# Input parameters
GITHUB_REPOSITORY="$1"
GITHUB_RUN_ID="$2"
GITHUB_RUN_ATTEMPT="$3"
GITHUB_WORKFLOW="$4"
GITHUB_JOB="$5"

# Base URLs
BASE_URL="https://github.com"
BUILD_URL="${BASE_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/attempts/${GITHUB_RUN_ATTEMPT}"

echo "Sending end request..."
curl -X POST "https://pse.invisirisk.com/end" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "builder=github" \
  -d "build_id=${GITHUB_RUN_ID}" \
  -d "build_url=${BUILD_URL}" \
  -d "project=${GITHUB_REPOSITORY}" \
  -d "workflow=${GITHUB_WORKFLOW} - ${GITHUB_JOB}"

# Get container ID
if [ -f /tmp/ir-container.id ]; then
    CONTAINER_ID=$(cat /tmp/ir-container.id)
    echo "Stopping container: $CONTAINER_ID"
    docker stop "$CONTAINER_ID" || true
    docker rm "$CONTAINER_ID" || true
    rm -f /tmp/ir-container.id
fi

echo "Cleanup completed successfully"
