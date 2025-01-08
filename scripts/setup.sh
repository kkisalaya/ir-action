#!/bin/sh

set -e

# Input parameters
SCAN_ID="$1"
GITHUB_REPOSITORY="$2"
GITHUB_RUN_ID="$3"
GITHUB_RUN_ATTEMPT="$4"
GITHUB_WORKFLOW="$5"
GITHUB_JOB="$6"
GITHUB_SHA="$7"
GITHUB_REF_NAME="$8"

# Clean up any existing container
docker rm -f ir-proxy 2>/dev/null || true

echo "Starting InvisiRisk container..."
CONTAINER_ID=$(docker run -d \
  --name ir-proxy \
  --privileged \
  --net=host \
  -v /sys/fs/bpf:/sys/fs/bpf \
  -v /sys/kernel/debug:/sys/kernel/debug \
  -v /lib/modules:/lib/modules:ro \
  -v /usr/src:/usr/src:ro \
  -e SCAN_ID="$SCAN_ID" \
  -e GITHUB_REPOSITORY="$GITHUB_REPOSITORY" \
  -e GITHUB_RUN_ID="$GITHUB_RUN_ID" \
  -e GITHUB_RUN_ATTEMPT="$GITHUB_RUN_ATTEMPT" \
  -e GITHUB_WORKFLOW="$GITHUB_WORKFLOW" \
  -e GITHUB_JOB="$GITHUB_JOB" \
  -e GITHUB_SHA="$GITHUB_SHA" \
  -e GITHUB_REF_NAME="$GITHUB_REF_NAME" \
  kkisalaya/ir-proxy:latest)

echo "Container ID: $CONTAINER_ID"

# Save container ID for cleanup immediately
echo "$CONTAINER_ID" > /tmp/ir-container.id

# Function to check container status
check_container() {
    echo "Checking container status..."
    docker ps -a --filter "id=$CONTAINER_ID" --format "{{.Status}}"
    echo "Container logs:"
    docker logs "$CONTAINER_ID" 2>&1 || true
}

# Initial check
check_container

# Give the container a moment to start
sleep 5

# Check if container is still running
if ! docker ps -q -f "id=$CONTAINER_ID" > /dev/null; then
    echo "Container failed to start or stopped unexpectedly!"
    check_container
    exit 1
fi

# Base URLs for start request
BASE_URL="https://github.com"
BUILD_URL="${BASE_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/attempts/${GITHUB_RUN_ATTEMPT}"

echo "Sending start request..."
curl -X POST "https://pse.invisirisk.com/start" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "builder=github" \
  -d "id=${SCAN_ID}" \
  -d "build_id=${GITHUB_RUN_ID}" \
  -d "build_url=${BUILD_URL}" \
  -d "project=${GITHUB_REPOSITORY}" \
  -d "workflow=${GITHUB_WORKFLOW} - ${GITHUB_JOB}" \
  -d "builder_url=${BASE_URL}" \
  -d "scm=git" \
  -d "scm_commit=${GITHUB_SHA}" \
  -d "scm_branch=${GITHUB_REF_NAME}" \
  -d "scm_origin=${BASE_URL}/${GITHUB_REPOSITORY}"

echo "Setup completed successfully"
