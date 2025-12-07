#!/bin/bash

# FILE: complete_setup.sh
# DESCRIPTION: Complete setup script - collects passwords interactively
# and runs all configuration scripts. This script combines first boot
# setup with the main configuration process.

echo "=============================================================="
echo "                 COMPLETING SETUP OF HOWLBACK"
echo "=============================================================="
echo ""
echo "This script will collect passwords for Pi-hole and Keepalived,"
echo "and then configure the remaining system functions including:"
echo "  - SSH Server"
echo "  - Firewall (UFW)"
echo "  - Unbound DNS Resolver"
echo "  - Pi-hole DNS Server"
echo "  - Keepalived High Availability"
echo "  - Manual DHCP Control Scripts"
echo ""

### Prompt for Pi-hole password with confirmation
while true; do
    echo "=== Pi-hole Web Interface Password ==="
    read -p "Enter password (will be visible): " PIHOLE_PASSWORD
    echo ""
    read -p "You entered: \"$PIHOLE_PASSWORD\" - Is this correct? (yes/no): " confirm
    if [ "$confirm" = "yes" ] || [ "$confirm" = "y" ]; then
        break
    fi
    echo "Let's try again..."
    echo ""
done

### Prompt for Keepalived password with confirmation
while true; do
    echo ""
    echo "=== Keepalived Authentication Password ==="
    read -p "Enter password (will be visible): " KEEPALIVED_PASSWORD
    echo ""
    read -p "You entered: \"$KEEPALIVED_PASSWORD\" - Is this correct? (yes/no): " confirm
    if [ "$confirm" = "yes" ] || [ "$confirm" = "y" ]; then
        break
    fi
    echo "Let's try again..."
    echo ""
done

echo ""
echo "Passwords collected. Running configuration scripts..."
echo ""

### SSH Server Setup
# ssh was installed by 'pkgsel' in the preseed file.
# This script applies additional configuration settings.
echo "Running setup_ssh.sh..."
/opt/setup_scripts/setup_ssh.sh

### Firewall (UFW) Setup
# ufw was installed by 'pkgsel' in the preseed file. 
# This script applies configuration settings.
echo "Running setup_ufw.sh..."
/opt/setup_scripts/setup_ufw.sh

### Unbound Setup
# unbound was installed by 'pkgsel' in the preseed file. 
# This script applies configuration settings.
echo "Running setup_unbound.sh..."
/opt/setup_scripts/setup_unbound.sh

### Pi-hole Setup
# Install and configure Pi-hole, using the collected password.
# The password is passed as an argument to the script.
echo "Running setup_pihole.sh..."
/opt/setup_scripts/setup_pihole.sh "$PIHOLE_PASSWORD"

### Keepalived Setup
# keepalived was installed by 'pkgsel' in the preseed file. 
# This script applies configuration settings using the collected password.
echo "Running setup_keepalived.sh..."
/opt/setup_scripts/setup_keepalived.sh "$KEEPALIVED_PASSWORD"

### Install manual DHCP control scripts
echo "Installing manual DHCP control scripts..."
cp /opt/setup_scripts/dhcp_enable.sh /usr/local/sbin/dhcp_enable.sh
cp /opt/setup_scripts/dhcp_disable.sh /usr/local/sbin/dhcp_disable.sh
chmod +x /usr/local/sbin/dhcp_enable.sh /usr/local/sbin/dhcp_disable.sh

### Completion message
echo ""
echo "=============================================================="
echo "                    CONFIGURATION COMPLETE"
echo "=============================================================="
echo ""
echo "All setup scripts completed successfully."
echo ""
echo "Howlback is now fully configured."
echo ""
echo "Press ENTER to continue..."
read

exit 0