#!/bin/bash

# FILE: setup_ssh.sh
# DESCRIPTION: A script to install and configure the SSH service.
# This script is designed to be called from the main complete_setup.sh script.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Setting up SSH and hardening..."

### Backup Original Config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

### Add Security Options
# Change SSH port from default (22) to 2222
# This handles multiple cases: commented, uncommented, with/without spaces
if grep -qE '^\s*#?\s*Port\s+' /etc/ssh/sshd_config; then
    # Port line exists, modify it
    sed -i -E 's/^\s*#?\s*Port\s+[0-9]+/Port 2222/' /etc/ssh/sshd_config
else
    # Port line doesn't exist, add it
    echo "Port 2222" >> /etc/ssh/sshd_config
fi

# Disable root login via ssh
# Handles various formats: "PermitRootLogin yes", "PermitRootLogin prohibit-password", etc.
if grep -qE '^\s*#?\s*PermitRootLogin\s+' /etc/ssh/sshd_config; then
    sed -i -E 's/^\s*#?\s*PermitRootLogin\s+.*/PermitRootLogin no/' /etc/ssh/sshd_config
else
    # Line doesn't exist, add it
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config
fi

### Verify configuration changes
echo "Verifying SSH configuration changes..."
if ! grep -q "^Port 2222" /etc/ssh/sshd_config; then
    echo "ERROR: Failed to set SSH port to 2222" >&2
    exit 1
fi

if ! grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
    echo "ERROR: Failed to disable root login" >&2
    exit 1
fi

echo "SSH configuration updated successfully."

### Test configuration before restarting
echo "Testing SSH configuration syntax..."
if ! sshd -t; then
    echo "ERROR: SSH configuration test failed" >&2
    echo "Restoring backup configuration..."
    cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
    exit 1
fi

### Restart SSH to apply the new configuration.
echo "Restarting SSH service to apply changes..."
systemctl restart ssh

### Completion Message
echo ""
echo "=============================================================="
echo "                      SSH Setup Complete"
echo "=============================================================="
echo "SSH is now listening on port 2222"
echo "Root login has been disabled"
echo ""