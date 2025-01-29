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

# Array of packages to install
packages="iptables curl wget nano"  # Add or remove packages as needed


# Function to install packages using apk
install_with_apk() {
    echo "Installing packages using apk..."
    apk update
    for package in $packages; do
        echo "Installing $package..."
        apk add "$package"
    done
}


# Function to install packages using apt-get
install_with_apt() {
    echo "Installing packages using apt-get..."
    sudo apt-get update
    for package in $packages; do
        echo "Installing $package..."
        sudo apt-get install -y "$package"
    done
}


# Check if apk is available
if command -v apk >/dev/null 2>&1; then
    install_with_apk
# If apk is not available, check if apt-get is available
elif command -v apt-get >/dev/null 2>&1; then
    install_with_apt
else
    echo "Error: Neither apk nor apt-get package manager found."
    exit 1
fi


echo "All packages installation completed."
mkdir ~/production
echo "Download PSE"
curl -o ~/pse https://ir-dev-public.s3.us-west-2.amazonaws.com/pse
echo "Download cfg"
curl -o ~/cfg.yaml https://ir-dev-public.s3.us-west-2.amazonaws.com/cfg.yaml
curl -o ~/production/leaks.toml https://ir-dev-public.s3.us-west-2.amazonaws.com/leaks.toml
curl -o ~/policy.json https://ir-dev-public.s3.us-west-2.amazonaws.com/policy.json

echo "Disable ipv6"
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
cat /proc/sys/net/ipv6/conf/all/disable_ipv6

echo "Starting proxy"
export INVISIRISK_PORTAL=https://app.dev.invisirisk.com
export INVISIRISK_JWT_TOKEN=1FL0OVuoSgeqy-y3T5cGGDjLGS4gaTRKtuTw4Jo9kwl8460Vz6lnnVvhrgh_FSTRmjYCsRgYEaxwBcuPP7Noyg
sudo chmod +x ~/pse
sudo -E ~/pse serve --policy ~/policy.json --config ~/cfg.yaml &
PSE_PID=$!

echo "Sleeping.."
sleep 5
echo "Running netstat"
sudo netstat -natup | grep 12345

echo "Setting up iptables..."
sudo iptables -t nat -N pse
sudo iptables -t nat -A OUTPUT -j pse


# Get the IP address of pse-proxy
#PSE_IP=$(curl -s ifconfig.me)
PSE_IP=127.0.0.1
echo "IP Address: $PSE_IP"
sudo iptables -t nat -A pse -p tcp -m tcp --dport 443 -j DNAT --to-destination $PSE_IP:12345
echo "Iptables setup completed."

echo "Verifying nat rules"
sudo iptables -t nat -L pse -v -n


echo "Setting up custom certificate..."
# Download the certificate
sudo curl -v -k https://pse.invisirisk.com/ca | sudo tee /etc/ssl/certs/pse.pem > /dev/null
sudo ln -sf /etc/ssl/certs/pse.pem /usr/local/share/ca-certificates/pse.crt
echo "Listing files in /etc/ssl/certs"
sudo ls -lrth /etc/ssl/certs/
# Update the CA certificates
sudo update-ca-certificates


# Configure Git
if command -v git >/dev/null 2>&1; then
    sudo git config --system http.sslCAInfo /etc/ssl/certs/pse.pem
    echo "Git configured to use custom certificate."
fi


# Configure npm
if command -v npm >/dev/null 2>&1; then
    sudo npm config set cafile /etc/ssl/certs/pse.pem
    echo "npm configured to use custom certificate."
fi

# Configure yarn
if command -v yarn >/dev/null 2>&1; then
    sudo yarn config set cafile /etc/ssl/certs/pse.pem
    echo "yarn configured to use custom certificate."
fi

# Configure Python pip
if command -v pip >/dev/null 2>&1; then
    sudo pip config --global set global.cert /etc/ssl/certs/pse.pem
    echo "pip configured to use custom certificate."
fi


# Set environment variables
sudo sh -c 'echo "export SSL_CERT_FILE=/etc/ssl/certs/pse.pem" >> /etc/environment'
sudo sh -c 'echo "export REQUESTS_CA_BUNDLE=/etc/ssl/certs/pse.pem" >> /etc/environment'
echo "Environment variables set for custom certificate."

echo "Custom certificate setup in Docker container completed."

echo "checking if custom certificate have been set correctly"
echo "Doing ls"
ls -l /etc/ssl/certs/pse.pem
ls -l /etc/ssl/certs | grep pse.pem
echo "Running openssl verify"
openssl s_client -connect example.com:443 -servername example.com -showcerts </dev/null 2>/dev/null | openssl x509 -out /tmp/example.crt
echo "Running openssl x509"
openssl verify -CAfile /etc/ssl/certs/pse.pem /tmp/example.crt
echo "Check environment variables for certs"
echo $SSL_CERT_FILE        # Should point to /etc/ssl/certs/pse.pem
echo $REQUESTS_CA_BUNDLE  # Should point to /etc/ssl/certs/pse.pem


# Main function
main() {
    # Environment variables
    base="https://base-url/"
    repo="https://github-repo"
    build_id=`hostname`
    build_url=https://build.com/`hostname`
    project=$SERVICE_NAME
    workflow="docker-compose"
    builder_url="https://builder-url"
    scm="git"
    scm_commit="commit"
    scm_branch="branch"
    scm_origin="origin"

    # Construct query parameters
    query="builder=github&build_id=$build_id&build_url=$build_url&project=$project&workflow=$workflow&builder_url=$builder_url&scm=$scm&scm_commit=$scm_commit&scm_branch=$scm_branch&scm_origin=$scm_origin"

    # Perform HTTP POST request using curl
    echo "Sending POST request..."
    curl -v -X POST -d "$query" -H "Content-Type: application/x-www-form-urlencoded" https://pse.invisirisk.com/start
}

# Execute main function
main
