#!/bin/bash

# FILE: manual_dhcp_disable.sh
# DESCRIPTION: Manually disable Pi-hole DHCP on secondary server
# USE CASE: Run this on the SECONDARY after the primary is back online
#           to return to normal operation

set -e

SETUPVARS="/etc/pihole/setupVars.conf"

echo "=============================================================="
echo "                  Manual DHCP Disable Script"
echo "=============================================================="
echo ""

# Verify Pi-hole is installed
if [ ! -f "$SETUPVARS" ]; then
    echo "ERROR: Pi-hole setupVars.conf not found. Is Pi-hole installed?" >&2
    exit 1
fi

# Warn the user
echo "This will disable DHCP on this server, Howlback."
echo ""
echo "Only run this if:"
echo "  1. The PRIMARY Pi-hole (Ravage) is back online"
echo "  2. Ravage is handling DHCP services"
echo "  3. You previously enabled DHCP on Howlback manually"
echo ""

# Confirmation prompt
read -p "Are you sure you want to disable DHCP? (yes/no): " -r CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted. DHCP remains enabled."
    exit 0
fi

echo ""
echo "Checking current DHCP status..."
CURRENT_STATUS=$(grep "^DHCP_ACTIVE=" "$SETUPVARS" | cut -d= -f2)
echo "Current DHCP_ACTIVE: $CURRENT_STATUS"

if [ "$CURRENT_STATUS" = "false" ]; then
    echo "DHCP is already disabled. Nothing to do."
    exit 0
fi

# Disable DHCP
echo ""
echo "Disabling DHCP..."
sed -i 's/^DHCP_ACTIVE=.*/DHCP_ACTIVE=false/' "$SETUPVARS"

# Restart Pi-hole to apply changes
echo "Restarting Pi-hole DNS service..."
pihole restartdns

# Verify DHCP is disabled with exponential backoff
echo "Verifying DHCP deactivation..."
SUCCESS=false
WAIT=1
for i in {1..5}; do
    NEW_STATUS=$(grep "^DHCP_ACTIVE=" "$SETUPVARS" | cut -d= -f2)
    
    if [ "$NEW_STATUS" = "false" ]; then
        SUCCESS=true
        break
    fi
    
    if [ $i -lt 5 ]; then
        echo "Attempt $i: DHCP not yet deactivated, waiting ${WAIT}s before retry..."
        sleep $WAIT
        WAIT=$((WAIT * 2))  # Double the wait time: 1, 2, 4, 8, 16 seconds
    fi
done

if [ "$SUCCESS" = true ]; then
    echo ""
    echo "=============================================================="
    echo "                 DHCP DISABLED SUCCESSFULLY"
    echo "=============================================================="
    echo "Server: Howlback"
    echo "Status: INACTIVE"
    echo ""
    echo "This server is now in BACKUP mode:"
    echo "  - DNS queries: Still being answered"
    echo "  - DHCP: Disabled (Ravage should handle this)"
    echo "  - Normal operation restored"
    echo "=============================================================="
else
    echo "ERROR: Failed to disable DHCP" >&2
    exit 1
fi

# Log the action
logger -t pihole-dhcp "DHCP manually disabled on Howlback"