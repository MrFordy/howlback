#!/bin/bash

# FILE: setup_pihole.sh
# DESCRIPTION: A script to install and configure Pi-hole with a secure setup.
# This script is designed to be called from the main setup_all.sh script.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Setting up Pi-hole..."

### Get Pi-hole password from argument
# The password is passed as the first argument to this script
PIHOLE_PASSWORD="$1"
if [ -z "$PIHOLE_PASSWORD" ]; then
    echo "ERROR: Pi-hole password was not provided as an argument." >&2
    exit 1
fi

### Disable `systemd-resolved` to prevent conflicts on port 53
echo "Disabling systemd-resolved to prevent port 53 conflict..."
systemctl disable systemd-resolved
systemctl stop systemd-resolved

### Perform a non-interactive installation of Pi-hole
echo "Performing non-interactive Pi-hole installation..."
export DNSMASQ_LISTENING=all
# Use Unbound as the upstream DNS server on localhost port 5353
export PIHOLE_DNS_="127.0.0.1#5353"
export INSTALL_WEB_SERVER=true
export INSTALL_WEB_INTERFACE=true
# Disable DHCP server as this is the Secondary instance
export DHCP_ACTIVE=false
export NTP_SERVER="ntp.org"
export PIHOLE_SKIP_INSTALL_CHECK=true

### Download and run the Pi-hole installer script
# The installer is fetched and piped directly to bash for execution
PIHOLE_INSTALLER=$(curl -fsSL https://install.pi-hole.net)
if [ $? -eq 0 ]; then
    echo "$PIHOLE_INSTALLER" | bash /dev/stdin
else
    echo "ERROR: Failed to download Pi-hole installer"
    exit 1
fi

### Set password for the Pi-hole web interface
echo "Applying Pi-hole password..."
pihole -a -p "$PIHOLE_PASSWORD"

### Add OISD blocklists and update the gravity database
echo "Adding OISD blocklists and updating gravity database..."
echo "https://big.oisd.nl/" | tee /etc/pihole/adlists.list >/dev/null
echo "https://nsfw.oisd.nl/" | tee -a /etc/pihole/adlists.list >/dev/null

pihole -g

### Add static DHCP leases from a separate file
# IP allocation explained in 04-pihole-static-dhcp.conf
echo "Adding static DHCP leases from separate file..."
if [ ! -f "/root/setup_scripts/04-pihole-static-dhcp.conf" ]; then
    echo "WARNING: No static DHCP leases file found. Skipping static lease configuration."
else
    cp /root/setup_scripts/04-pihole-static-dhcp.conf /etc/dnsmasq.d/04-pihole-static-dhcp.conf
    pihole restartdns
fi

### Final system configuration
echo "Configuring host system DNS to use Pi-hole..."
echo "nameserver 127.0.0.1" > /etc/resolv.conf

### Test Pi-hole to ensure it is working correctly
echo "Testing Pi-hole ad-blocking..."
if dig @127.0.0.1 doubleclick.net | grep "0.0.0.0" > /dev/null; then
    echo "Pi-hole is blocking ads correctly. Test successful."
else
    echo "ERROR: Pi-hole test failed. 'doubleclick.net' was not blocked."
    exit 1
fi

echo "Testing Pi-hole resolves a legitimate domain..."
if dig @127.0.0.1 google.com | grep -v "0.0.0.0" > /dev/null; then
    echo "Pi-hole is resolving legitimate domains correctly. Test successful."
else
    echo "ERROR: Pi-hole test failed. 'google.com' was incorrectly blocked."
    exit 1
fi

### Completion Message
echo ""
echo "=============================================================="
echo "                   Pi-hole Setup Complete"
echo "=============================================================="
echo ""