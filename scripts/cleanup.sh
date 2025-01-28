#!/bin/sh

set -e

# Input parameters
main() {

    build_url=https://build.com/`hostname`
    status="success"

    # Construct query parameters
    query="build_url=$build_url&status=$status"

    # Perform HTTP POST request using curl
    echo "Sending POST request..."
    curl -X POST -d "$query" -H "Content-Type: application/x-www-form-urlencoded" https://pse.invisirisk.com/end
}

# Execute main function
main
