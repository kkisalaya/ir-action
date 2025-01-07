#!/bin/sh

set -e

# Input parameters
SCAN_ID="$1"
DENAT_URL="$2"
PSE_URL="$3"
GITHUB_REPOSITORY="$4"
GITHUB_RUN_ID="$5"
GITHUB_RUN_ATTEMPT="$6"
GITHUB_WORKFLOW="$7"
GITHUB_JOB="$8"
GITHUB_SHA="$9"
GITHUB_REF_NAME="${10}"

# Install required tools
apk add --no-cache curl wget libelf

# Download tools
echo "Downloading denat tool..."
wget -O denat "$DENAT_URL"
chmod +wx denat
ldd denat

echo "Downloading PSE tool..."
wget -O pse "$PSE_URL"
chmod +x pse

echo "Download config file..."
wget -O cfg.yaml "https://ir-dev-public.s3.us-west-2.amazonaws.com/cfg.yaml"

ls -lrth

ls -lrth /

# Get container IP
CONTAINER_IP=$(hostname -i | awk '{print $1}')
echo "Container IP: $CONTAINER_IP"

# Start denat
echo "Starting denat..."
./denat -dfproxy="${CONTAINER_IP}:12345" -dfports=80,443 &
DENAT_PID=$!

# Start PSE proxy
echo "Starting PSE proxy..."
./pse serve --certsetup &
PSE_PID=$!

# Store PIDs for cleanup
echo "$DENAT_PID" > /tmp/denat.pid
echo "$PSE_PID" > /tmp/pse.pid

# Prepare and send start request
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
