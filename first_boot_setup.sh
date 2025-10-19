#!/bin/bash

# FILE: first_boot_setup.sh
# DESCRIPTION: First boot setup script - collects passwords interactively
# and runs the main configuration scripts. This script is called by a
# systemd service on first boot after installation.

echo "=============================================================="
echo "              HOWLBACK FIRST BOOT CONFIGURATION"
echo "=============================================================="
echo ""
echo "This script will collect passwords for Pi-hole and Keepalived."
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

### Save passwords securely
echo "$PIHOLE_PASSWORD" > /root/.pihole-password
echo "$KEEPALIVED_PASSWORD" > /root/.keepalived-password
chmod 600 /root/.pihole-password /root/.keepalived-password

echo ""
echo "Passwords saved. Running configuration scripts..."
echo ""

### Run the main setup script
bash /root/setup_scripts/setup_all.sh "$PIHOLE_PASSWORD" "$KEEPALIVED_PASSWORD"

### Remove the systemd service
systemctl disable first-boot-setup.service
rm -f /etc/systemd/system/first-boot-setup.service

# Note: This script is NOT removed - it stays in /root/setup_scripts/
# in case you need to reference it or run it again manually.

echo ""
echo "=============================================================="
echo "                    CONFIGURATION COMPLETE"
echo "=============================================================="
echo ""
echo "Howlback is now fully configured."
echo "You can log in normally with the howlback-admin account."
echo ""
echo "Press ENTER to continue..."
read

exit 0