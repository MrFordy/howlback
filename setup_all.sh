#!/bin/bash

# FILE: setup_all.sh
# DESCRIPTION: Main setup script executed by the preseed late_command.
# It calls individual setup scripts for ufw, ssh, unbound, pihole, and 
# keepalived. It collects the pi-hole and keepalived passwords
# as arguments and passes them to the appropriate setup scripts.
# Nebula-synce is not installed as Howlback is the secondary instance.

### Retrieve Pi-hole and Keepalived passwords
PIHOLE_PASSWORD="$1"
KEEPALIVED_PASSWORD="$2"
# Check if the Pi-hole password was received.
if [ -z "$PIHOLE_PASSWORD" ]; then
    echo "Error: Pi-hole password was not passed as an argument."
    exit 1
fi
# Check if the Keepalived password was received.
if [ -z "$KEEPALIVED_PASSWORD" ]; then
    echo "Error: Keepalived password was not passed as an argument."
    exit 1
fi

### Firewall (UFW) Setup
# ufw was insalled by 'tasksel' in the preseed file. This script
# applies configuration settings.
echo "Running setup_ufw.sh..."
/root/setup_scripts/setup_ufw.sh

### SSH Server Setup
# ssh was installed by 'tasksel' in the preseed file. This script
# applies additional configuration settings.
echo "Running setup_ssh.sh..."
/root/setup_scripts/setup_ssh.sh

### Unbound Setup
# Install and configure the Unbound recursive DNS resolver.
echo "Running setup_unbound.sh..."
/root/setup_scripts/setup_unbound.sh

### Pi-hole Setup
# Install and configure Pi-hole, using the collected password.
# The password is passed as an argument to the script.
echo "Running setup_pihole.sh..."
/root/setup_scripts/setup_pihole.sh "$PIHOLE_PASSWORD"

### Keepalived Setup
# Configure Keepalived, using the collected password.
# The 'keepalived' package is included in pkgsel/include.
# The password is passed as an argument to the script.
echo "Running setup_keepalived.sh..."
/root/setup_scripts/setup_keepalived.sh "$KEEPALIVED_PASSWORD"

### Install manual DHCP control scripts
echo "Installing manual DHCP control scripts..."
cp /root/setup_scripts/manual_dhcp_enable.sh /usr/local/sbin/manual_dhcp_enable.sh
cp /root/setup_scripts/manual_dhcp_disable.sh /usr/local/sbin/manual_dhcp_disable.sh
chmod +x /usr/local/sbin/manual_dhcp_enable.sh /usr/local/sbin/manual_dhcp_disable.sh

### Completion message
echo "=============================================================="
echo "         All setup scripts completed successfully"
echo "=============================================================="

exit 0