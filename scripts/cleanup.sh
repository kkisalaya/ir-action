#!/bin/sh

set -e

# Input parameters
GITHUB_REPOSITORY="$1"
GITHUB_RUN_ID="$2"
GITHUB_RUN_ATTEMPT="$3"
GITHUB_RUN_RESULT="$4"

# Read PIDs
DENAT_PID=$(cat /tmp/denat.pid)
PSE_PID=$(cat /tmp/pse.pid)

# Prepare and send end request
BASE_URL="https://github.com"
BUILD_URL="${BASE_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/attempts/${GITHUB_RUN_ATTEMPT}"

echo "Sending end request..."
curl -X POST "https://pse.invisirisk.com/end" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "build_url=${BUILD_URL}" \
  -d "status=${GITHUB_RUN_RESULT}"

# Kill processes
if [ -n "$DENAT_PID" ]; then
  echo "Stopping denat process..."
  kill "$DENAT_PID" || true
fi

if [ -n "$PSE_PID" ]; then
  echo "Stopping PSE process..."
  kill "$PSE_PID" || true
fi

echo "Cleanup completed successfully"
