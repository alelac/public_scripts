#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=========================================="
echo " Starting System Update and Configuration "
echo "=========================================="

# 1. Update, Upgrade, and Clean Up
echo "--> Updating package lists..."
sudo apt-get update -y

echo "--> Upgrading packages..."
sudo apt-get upgrade -y

echo "--> Removing unnecessary packages..."
sudo apt-get autoremove -y

# 2. Install requested utilities
echo "--> Installing ssh, neofetch, and vim..."
sudo apt-get install -y ssh neofetch vim

# 3. Define target .bashrc files
# This gathers /root, /etc/skel, and all existing user homes in /home
BASHRC_FILES=("/root/.bashrc" "/etc/skel/.bashrc")

for home_dir in /home/*; do
    if [ -d "$home_dir" ] && [ -f "$home_dir/.bashrc" ]; then
        BASHRC_FILES+=("$home_dir/.bashrc")
    fi
done

# 4. Apply standard modifications to ALL target .bashrc files
echo "--> Applying standard .bashrc modifications..."
for rc_file in "${BASHRC_FILES[@]}"; do
    if [ -f "$rc_file" ]; then
        echo "    Modifying: $rc_file"
        
        # Uncomment force_color_prompt=yes
        sudo sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/' "$rc_file"
        
        # Change alias l='ls -CF' to alias l='ls -laFh'
        # Using alternate sed delimiter | because of the forward slash in the alias
        sudo sed -i "s|alias l='ls -CF'|alias l='ls -laFh'|" "$rc_file"
    fi
done

# 5. Apply the specific Root color change (Green 32m -> Red 31m)
ROOT_BASHRC="/root/.bashrc"
if [ -f "$ROOT_BASHRC" ]; then
    echo "--> Changing Root prompt color to Red..."
    # Targets the specific 01;32m inside the PS1 variable string
    sudo sed -i 's/01;32m/01;31m/g' "$ROOT_BASHRC"
fi

echo "=========================================="
echo "       Configuration Complete!            "
echo "=========================================="
