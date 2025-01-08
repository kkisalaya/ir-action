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

echo "Starting InvisiRisk container..."
docker run -d \
  --name ir-action \
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
  kkisalaya/ir-action:latest

# Wait for container to start and initialize
echo "Waiting for services to initialize..."
sleep 5

# Get container ID
CONTAINER_ID=$(docker ps -q -f name=ir-action)
echo "Container ID: $CONTAINER_ID"

# Show container logs
echo "=== Container Logs ==="
docker logs ir-action

# Save container ID for cleanup
echo "$CONTAINER_ID" > /tmp/ir-container.id
