#!/bin/sh

set -e

# Input parameters
SCAN_ID="$1"
PACKAGE_URL="$2"
GITHUB_REPOSITORY="$3"
GITHUB_RUN_ID="$4"
GITHUB_RUN_ATTEMPT="$5"
GITHUB_WORKFLOW="$6"
GITHUB_JOB="$7"
GITHUB_SHA="$8"
GITHUB_REF_NAME="$9"

# Get the directory where setup.sh is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Downloading package..."
wget --verbose --timeout=60 --tries=3 --progress=bar:force:noscroll \
    --no-check-certificate -O package.tar.gz "$PACKAGE_URL" || {
    echo "Failed to download package"
    rm -f package.tar.gz
    exit 1
}

echo "Extracting package..."
tar xzf package.tar.gz || {
    echo "Failed to extract package"
    rm -f package.tar.gz
    exit 1
}

# Verify required files exist
for file in denat pse cfg.yaml; do
    if [ ! -f "$file" ]; then
        echo "Required file $file not found in package"
        rm -f package.tar.gz
        exit 1
    fi
done

# Make executables
chmod +x denat pse

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

# Clean up the archive
rm -f package.tar.gz

# Save PIDs for cleanup
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
