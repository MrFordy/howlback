#!/bin/bash

# FILE: dhcp_enable.sh
# DESCRIPTION: Manually enable Pi-hole DHCP on secondary server
# USE CASE: Run this on the SECONDARY when the primary is offline
#           and you need to restore DHCP services manually

set -e

SETUPVARS="/etc/pihole/setupVars.conf"

echo "=============================================================="
echo "                  MANUAL DHCP ENABLE SCRIPT"
echo "=============================================================="
echo ""

# Verify Pi-hole is installed
if [ ! -f "$SETUPVARS" ]; then
    echo "ERROR: Pi-hole setupVars.conf not found. Is Pi-hole installed?" >&2
    exit 1
fi

# Warn the user
echo "WARNING: This will enable DHCP on this server, Howlback."
echo ""
echo "Only run this if:"
echo "  1. The PRIMARY Pi-hole (Ravage) is offline/down."
echo "  2. You need to manually restore DHCP service"
echo ""
echo "Running DHCP on both servers simultaneously will cause"
echo "network conflicts and IP address problems!"
echo ""

# Confirmation prompt
read -p "Are you sure you want to enable DHCP? (yes/no): " -r CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted. DHCP not enabled."
    exit 0
fi

echo ""
echo "Checking current DHCP status..."
CURRENT_STATUS=$(grep "^DHCP_ACTIVE=" "$SETUPVARS" | cut -d= -f2)
echo "Current DHCP_ACTIVE: $CURRENT_STATUS"

if [ "$CURRENT_STATUS" = "true" ]; then
    echo "DHCP is already enabled. Nothing to do."
    exit 0
fi

# Configure DHCP parameters if not already present
echo ""
echo "Ensuring DHCP parameters are configured..."

# Check if DHCP range is configured
if ! grep -q "^DHCP_START=" "$SETUPVARS"; then
    echo "Adding DHCP configuration..."
    cat >> "$SETUPVARS" << 'EOF'

# DHCP Configuration
DHCP_START=192.168.0.200
DHCP_END=192.168.0.249
DHCP_ROUTER=192.168.0.1
DHCP_LEASETIME=24
PIHOLE_DOMAIN=lan
DHCP_IPv6=false
DHCP_rapid_commit=false
EOF
    echo "DHCP parameters added to setupVars.conf"
else
    echo "DHCP parameters already configured"
fi

# Enable DHCP
echo ""
echo "Enabling DHCP..."
sed -i 's/^DHCP_ACTIVE=.*/DHCP_ACTIVE=true/' "$SETUPVARS"

# Restart Pi-hole to apply changes
echo "Restarting Pi-hole DNS service..."
pihole restartdns

### Verify DHCP is enabled
# Exponential backoff, max ~31 seconds.
echo "Verifying DHCP activation..."
SUCCESS=false
WAIT=1
for i in {1..6}; do
    NEW_STATUS=$(grep "^DHCP_ACTIVE=" "$SETUPVARS" | cut -d= -f2)
    
    if [ "$NEW_STATUS" = "true" ]; then
        SUCCESS=true
        break
    fi
    
    if [ $i -lt 6 ]; then
        echo "Attempt $i: DHCP not yet activated, waiting ${WAIT}s before retry..."
        sleep $WAIT
        WAIT=$((WAIT * 2))  # Double the wait time: 1, 2, 4, 8, 16 seconds
    fi
done


if [ "$SUCCESS" = "true" ]; then
    echo ""
    echo "=============================================================="
    echo "                  DHCP ENABLED SUCCESSFULLY"
    echo "=============================================================="
    echo "Server: Howlback"
    echo "DHCP Range: 192.168.0.200 - 192.168.0.249"
    echo "Status: ACTIVE"
    echo ""
    echo "IMPORTANT REMINDERS:"
    echo "  - Howlback is now providing DHCP services"
    echo "  - Do NOT bring the Ravage back online with DHCP enabled"
    echo "  - Run manual-dhcp-disable.sh when Ravage is restored"
    echo "=============================================================="
    # Log the action
    logger -t pihole-dhcp "DHCP manually enabled on Howlback"   
else
    echo "ERROR: Failed to enable DHCP" >&2
    logger -t pihole-dhcp "ERROR: Failed to manually enable DHCP on Howlback"
    exit 1
fi
