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
#apk add --no-cache curl wget file iproute2

# Download tools with better handling for large files
echo "Downloading denat tool..."
wget --verbose --timeout=60 --tries=3 --continue --progress=bar:force:noscroll \
    --no-check-certificate --max-redirect=5 -O denat "$DENAT_URL" || {
    echo "Failed to download denat tool"
    exit 1
}
chmod +wx denat
#file denat
#which ip
#ln -s /sbin/ip /usr/bin/ip

echo "Download config file..."
wget --verbose --timeout=60 --tries=3 --continue --progress=bar:force:noscroll \
    --no-check-certificate --max-redirect=5 -O cfg.yaml "https://ir-dev-public.s3.us-west-2.amazonaws.com/cfg.yaml" || {
    echo "Failed to download config file"
    exit 1
}

echo "Downloading PSE tool..."
# Try wget first with continue support
for i in $(seq 1 3); do
    echo "Attempt $i to download PSE..."
    if wget --verbose --timeout=60 --tries=1 --continue --progress=bar:force:noscroll \
        --no-check-certificate --max-redirect=5 -O pse "$PSE_URL"; then
        break
    fi
    echo "Download attempt $i failed, waiting before retry..."
    sleep 5
done

# Verify the download
if [ ! -s pse ]; then
    echo "PSE download failed after 3 attempts"
    exit 1
fi

chmod +x pse

# Add memory and system info for debugging
echo "System Memory Status:"
free -h
echo "System Load:"
uptime
echo "Network Status:"
netstat -tuln

ls -lrth

ls -lrth /

# Get container IP
CONTAINER_IP=$(hostname -i | awk '{print $1}')
echo "Container IP: $CONTAINER_IP"

# Start denat
echo "Starting denat..."
sudo ./denat -dfproxy="${CONTAINER_IP}:12345" -dfports=80,443 &
DENAT_PID=$!

# Start PSE proxy
echo "Starting PSE proxy..."
sudo ./pse serve --certsetup &
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
