#!/bin/bash

# FILE: setup_ssh.sh
# DESCRIPTION: A script to install and configure the SSH service.
# This script is designed to be called from the main setup_all.sh script.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Setting up SSH and hardening..."

### Backup Original Config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

### Add Security Options
# These commands use sed to modify the /etc/ssh/sshd_config file in place.
# Changes ssh from port 22 to port 2222.
sed -i 's/^#\?Port 22/Port 2222/' /etc/ssh/sshd_config
# Disable root login via ssh.
sed -i 's/^#\?PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

### Restart SSH to apply the new configuration.
echo "Restarting SSH service to apply changes..."
systemctl restart ssh

### Completion Message
echo ""
echo "=============================================================="
echo "                      SSH Setup Complete"
echo "=============================================================="
echo ""

