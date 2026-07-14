#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define Color Codes
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color (Reset)

# Helper function for yellow output
yecho() {
    echo -e "${YELLOW}$1${NC}"
}

# Helper function for red output
recho() {
    echo -e "${RED}$1${NC}"
}

# CRITICAL: Force the script to be run with sudo/root privileges
if [ "$EUID" -ne 0 ]; then
    recho "Error: This script must be run with sudo or as root!"
    yecho "Please try running: sudo $0"
    exit 1
fi

yecho "=========================================="
yecho " Starting System Update and Configuration "
yecho "=========================================="

# 1. Update, Upgrade, and Clean Up
yecho "--> Updating package lists..."
apt-get update -y

yecho "--> Upgrading packages..."
apt-get upgrade -y

yecho "--> Removing unnecessary packages..."
apt-get autoremove -y

# 2. Install requested utilities
yecho "--> Installing ssh, neofetch, and vim..."
apt-get install -y ssh neofetch vim

# 3. Define target .bashrc files
BASHRC_FILES=("/root/.bashrc" "/etc/skel/.bashrc")

for home_dir in /home/*; do
    if [ -d "$home_dir" ] && [ -f "$home_dir/.bashrc" ]; then
        BASHRC_FILES+=("$home_dir/.bashrc")
    fi
done

# 4. Apply standard modifications to ALL target .bashrc files
yecho "--> Applying standard .bashrc modifications..."
for rc_file in "${BASHRC_FILES[@]}"; do
    if [ -f "$rc_file" ]; then
        yecho "    Modifying: $rc_file"
        
        # 4a. Uncomment force_color_prompt=yes (flexible regex matching)
        if grep -q "force_color_prompt=yes" "$rc_file"; then
            # If it exists but is commented out, uncomment it
            if grep -q "#[[:space:]]*force_color_prompt=yes" "$rc_file"; then
                sed -i 's/#[[:space:]]*force_color_prompt=yes/force_color_prompt=yes/' "$rc_file"
            else
                yecho "    (force_color_prompt=yes is already active)"
            fi
        else
            recho "    [ERROR] 'force_color_prompt=yes' does not exist in $rc_file"
        fi
        
        # 4b. Change alias l='ls -CF' to alias l='ls -laFh'
        # This regex accounts for potential single/double quote variations or spacing
        if grep -qE "alias l=['\"]ls -CF['\"]" "$rc_file"; then
            sed -i "s|alias l=['\"]ls -CF['\"]|alias l='ls -laFh'|g" "$rc_file"
        else
            recho "    [ERROR] \"alias l='ls -CF'\" not found in $rc_file"
        fi
    fi
done

# 5. Apply the specific Root color change (Green 32m -> Red 31m)
ROOT_BASHRC="/root/.bashrc"
if [ -f "$ROOT_BASHRC" ]; then
    yecho "--> Changing Root prompt color to Red..."
    if grep -q "01;32m" "$ROOT_BASHRC"; then
        sed -i 's/01;32m/01;31m/g' "$ROOT_BASHRC"
    else
        recho "    [ERROR] '01;32m' color code not found in $ROOT_BASHRC"
    fi
fi

yecho "=========================================="
yecho "        Configuration Complete!           "
yecho "=========================================="
