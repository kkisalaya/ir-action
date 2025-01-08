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

# Function to check container status
check_container() {
    echo "Checking container status..."
    docker ps -a --filter "id=$CONTAINER_ID" --format "{{.Status}}"
    echo "Container logs:"
    docker logs "$CONTAINER_ID"
    echo "Container processes:"
    docker top "$CONTAINER_ID" || true
}

# Initial container status
check_container

# Wait and check status every second for 30 seconds
for i in $(seq 1 30); do
    echo "Wait iteration $i/30..."
    sleep 1
    
    # Check if container is still running
    if ! docker ps -q -f "id=$CONTAINER_ID" > /dev/null; then
        echo "Container stopped unexpectedly!"
        echo "Final container status:"
        check_container
        exit 1
    fi

    # Show current status every 5 seconds
    if [ $((i % 5)) -eq 0 ]; then
        check_container
    fi
done

# Final status check
echo "Final container status:"
check_container

# Save container ID for cleanup
echo "$CONTAINER_ID" > /tmp/ir-container.id
