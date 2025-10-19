#!/bin/bash

# FILE: setup_keepalived.sh
# DESCRIPTION: A script to install and configure Keepalived for high availability.
# This script sets up a VRRP instance to manage a virtual IP address, making
# the Pi-hole service redundant. It is designed to be called from the main 
# setup_all.sh script with the Keepalived password as an argument.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Setting up Keepalived for Pi-hole high availability..."

### Retrieve Keepalived password from argument
# The password is passed as an argument when this script is called.
KEEPALIVED_PASSWORD="$1"

# Validate that the password was provided
if [ -z "$KEEPALIVED_PASSWORD" ]; then
    echo "ERROR: Keepalived password was not passed as an argument." >&2
    exit 1
fi

echo "Using provided Keepalived password."
echo "IMPORTANT: Use this same password on all other Keepalived nodes."

### Dynamically determine the primary network interface
# This identifies the interface used for the default route.
echo "Detecting primary network interface..."
PRIMARY_INTERFACE=$(ip route get 1.1.1.1 | awk '{print $5}')
if [ -z "$PRIMARY_INTERFACE" ]; then
    echo "ERROR: Could not determine the primary network interface." >&2
    exit 1
fi
echo "Primary network interface detected: $PRIMARY_INTERFACE"

### Create the Keepalived configuration file
# This configuration defines a VRRP instance that will manage the virtual IP.
# This server is configured as the MASTER. Other nodes should be set to BACKUP.
echo "Creating Keepalived configuration file..."
cat > /etc/keepalived/keepalived.conf << EOF
vrrp_instance VI_1 {
    # This server is the secondary (BACKUP). Other nodes should be MASTER.
    state BACKUP
    # The network interface to monitor, detected dynamically.
    interface $PRIMARY_INTERFACE
    # Virtual router ID must be the same on all nodes in the cluster (1-255).
    virtual_router_id 51
    # The BACKUP should have a lower priority than MASTER nodes.
    priority 50

    # Use unicast for security, specifying the IP of the MASTER server.
    unicast_peer {
        192.168.0.250
    }

    # Authentication block for security.
    # All nodes in the cluster MUST use the same password.
    authentication {
        auth_type PASS
        auth_pass $KEEPALIVED_PASSWORD
    }

    # The virtual IP address that will be shared.
    # This is the IP that clients will use to connect to the service.
    virtual_ipaddress {
        192.168.0.2/24
    }
}
EOF

### Enable and Start Keepalived
# This ensures that Keepalived starts automatically on boot.
echo "Enabling and starting Keepalived service..."
systemctl enable keepalived
systemctl start keepalived

### Test Keepalived
# Check if the service is active and running.
echo "Testing Keepalived service..."
if systemctl is-active --quiet keepalived; then
    echo "Keepalived service is active and running."
else
    echo "ERROR: Keepalived service failed to start." >&2
    exit 1
fi

### Wait for the virtual IP to be assigned
# Exponential backoff, max ~31 seconds.
echo "Verifying virtual IP address..."
SUCCESS=false
WAIT=1
for i in {1..5}; do
    if ip addr show $PRIMARY_INTERFACE | grep -q "192.168.0.2"; then
        echo "Virtual IP 192.168.0.2 is correctly configured on $PRIMARY_INTERFACE."
        SUCCESS=true
        break
    fi
    if [ $i -lt 5 ]; then
        echo "Attempt $i: Virtual IP not yet assigned, waiting ${WAIT}s before retry..."
        sleep $WAIT
        WAIT=$((WAIT * 2))  # Double the wait time: 1, 2, 4, 8, 16 seconds
    fi
done

if [ "$SUCCESS" = false ]; then
    echo "ERROR: Virtual IP address was not assigned after multiple attempts."
    echo "Check Keepalived logs with: journalctl -u keepalived -n 20"
    exit 1
fi

### Check if the virtual IP is present on the interface
echo "Verifying virtual IP address..."
if ip addr show $PRIMARY_INTERFACE | grep -q "192.168.0.2"; then
    echo "Virtual IP 192.168.0.2 is correctly configured on $PRIMARY_INTERFACE."
else
    echo "WARNING: Virtual IP address was not found. Check Keepalived logs."
fi

### Completion Message
echo ""
echo "=============================================================="
echo "                   Keepalived Setup Complete"
echo "=============================================================="
echo ""