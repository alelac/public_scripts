#!/bin/bash
# Exit script if any command fails
set -e


# Define Color Codes
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color (Reset)

# Helper function for yellow output
yecho() {
    echo -e "${YELLOW}$1${NC}"
}
# Helper function for red output
recho() {
    echo -e "${RED}$1${NC}"
}
# Helper function for blue output
becho() {
    echo -e "${BLUE}$1${NC}"
}
# Helper function for green output
gecho() {
    echo -e "${GREEN}$1${NC}"
}

# Define the function
confirm_or_exit() {
    # Force read to look at the terminal keyboard
    read -p "Do you want to continue? (y/N): " response < /dev/tty
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        recho "Exiting script."
        exit 1
    fi
}


get_secure_password() {
    local prompt_msg="$1"
    local -n target_var="$2"
    local passwd1 passwd2
    
    while true; do
        # Add < /dev/tty to both read commands here
        read -sp "$prompt_msg: " passwd1 < /dev/tty
        echo ""
        read -sp "Confirm password: " passwd2 < /dev/tty
        echo ""
        
        if [ "$passwd1" = "$passwd2" ] && [ -n "$passwd1" ]; then
            target_var="$passwd1"
            break
        else
            recho "Passwords do not match or are empty. Please try again."
            echo "--------------------------------------------------"
        fi
    done
}





becho "==========================================="
becho " OwnCloud Docker Compose Deployment Script "
becho " by alelac 2026-07-14                      "
becho "==========================================="
echo ""

# Ensure the script is run with sudo/root privileges
if [ "$EUID" -ne 0 ]; then
    recho "Error: This script must be run as root or with sudo."
    exit 1
fi


# Install dependencies early so we can safely use curl and jq
becho "Installing dependencies (docker.io, docker-compose-v2, curl, jq)..."
apt-get update && apt-get install -y docker.io docker-compose-v2 curl jq

# Explicit verification block
becho "Verifying dependencies..."
MISSING_PKGS=()

for pkg in docker.io docker-compose-v2 curl jq; do
    if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
    recho "❌ ERROR: The following dependencies failed to install correctly: ${MISSING_PKGS[*]}"
    recho "Please check your network connections or apt repositories and try again."
    exit 1
else
    gecho "✅ All dependencies verified and installed successfully!"
fi




becho "Fetching the latest stable OwnCloud version..."

# Look up the latest version string
LATEST_VERSION=$(curl -s "https://hub.docker.com/v2/repositories/owncloud/server/tags?page_size=100" | \
  jq -r '.results[].name' | \
  grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | \
  sort -V | tail -n 1 || true)

if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION="10.16.3"
    yecho "Could not retrieve version from Docker Hub. Defaulting to ${LATEST_VERSION}."
else
    gecho "Latest stable version identified: $LATEST_VERSION"
fi

confirm_or_exit


# Create subfolder for owncloud docker files
DIR_NAME="/opt/docker/owncloud"
# 1. If the directory doesn't exist, create it
if [ ! -d "$DIR_NAME" ]; then
    gecho "Directory '$DIR_NAME' does not exist. Creating it..."
    mkdir -p "$DIR_NAME"
fi
# 2. Check if the directory is NOT empty
# (Matches any file/folder inside, excluding '.' and '..')
if [ "$(ls -A "$DIR_NAME" 2>/dev/null)" ]; then
    recho "WARNING: Directory '$DIR_NAME' already exists and is NOT empty."
    read -p "Do you want to proceed and potentially overwrite files? (y/N): " proceed < /dev/tty
    if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
        yecho "Aborting script to protect existing files."
        exit 1
    fi
else
    gecho "Directory '$DIR_NAME' is empty and ready to use."
fi
# 3. Safely enter the directory
cd "$DIR_NAME" || { recho "Failed to enter directory $DIR_NAME"; exit 1; }


# User inputs for environment file
read -p "Enter OwnCloud Domain/FQDN (e.g., owncloud.local): " FQDN < /dev/tty
read -p "Enter Admin Username [admin]: " OCADMIN < /dev/tty
OCADMIN=${OCADMIN:-admin}
get_secure_password "Enter Admin Password" OCPASSWD
get_secure_password "Enter Owncloud Database User Password" OCDBPWD
get_secure_password "Enter MySQL Root Password" ROOTDBPWD


# Create .env file
becho "Creating environment file..."
cat << EOF > .env
OWNCLOUD_VERSION=${LATEST_VERSION}
OWNCLOUD_DOMAIN=${FQDN}:8080
OWNCLOUD_TRUSTED_DOMAINS=localhost,${FQDN}
ADMIN_USERNAME=${OCADMIN}
ADMIN_PASSWORD=${OCPASSWD}
HTTP_PORT=8080
OC_DB_NAME=owncloud
OC_DB_USERNAME=owncloud
OC_DB_PASSWORD=${OCDBPWD}
MYSQL_ROOT_PWD=${ROOTDBPWD}
EOF


becho "Creating docker-compose.yml..."
cat << 'EOF' > docker-compose.yml
volumes:
  files:
    driver: local
  mysql:
    driver: local
  redis:
    driver: local

services:
  owncloud:
    image: owncloud/server:${OWNCLOUD_VERSION}
    container_name: owncloud_server
    restart: always
    ports:
      - ${HTTP_PORT}:8080
    depends_on:
      - mariadb
      - redis
    environment:
      - OWNCLOUD_DOMAIN=${OWNCLOUD_DOMAIN}
      - OWNCLOUD_TRUSTED_DOMAINS=${OWNCLOUD_TRUSTED_DOMAINS}
      - OWNCLOUD_DB_TYPE=mysql
      - OWNCLOUD_DB_NAME=${OC_DB_NAME}
      - OWNCLOUD_DB_USERNAME=${OC_DB_USERNAME}
      - OWNCLOUD_DB_PASSWORD=${OC_DB_PASSWORD}
      - OWNCLOUD_DB_HOST=mariadb
      - OWNCLOUD_ADMIN_USERNAME=${ADMIN_USERNAME}
      - OWNCLOUD_ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - OWNCLOUD_MYSQL_UTF8MB4=true
      - OWNCLOUD_REDIS_ENABLED=true
      - OWNCLOUD_REDIS_HOST=redis
    healthcheck:
      test: ["CMD", "/usr/bin/healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 5
    volumes:
      - files:/mnt/data

  mariadb:
    image: mariadb:10.11
    container_name: owncloud_mariadb
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PWD}
      - MYSQL_USER=${OC_DB_USERNAME}
      - MYSQL_PASSWORD=${OC_DB_PASSWORD}
      - MYSQL_DATABASE=${OC_DB_NAME}
      - MARIADB_AUTO_UPGRADE=1
    command: ["--max-allowed-packet=128M", "--innodb-log-file-size=64M"]
    healthcheck:
      test: ["CMD-SHELL", "mariadb-admin ping -u root -p$$MYSQL_ROOT_PASSWORD"]
      interval: 10s
      timeout: 5s
      retries: 5
    volumes:
      - mysql:/var/lib/mysql

  redis:
    image: redis:6
    container_name: owncloud_redis
    restart: always
    command: ["--databases", "1"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    volumes:
      - redis:/data
EOF


becho "Spinning up containers..."
sudo docker compose up -d

gecho "Finished!"
gecho "You can find the docker-compose and env files in ${DIR_NAME}"
echo ""
