#!/bin/bash

# FILE: setup_keepalived.sh
# DESCRIPTION: A script to install and configure Keepalived for high availability.
# This script sets up a VRRP instance to manage a virtual IP address, making
# the Pi-hole service redundant. It is designed to be called from the main 
# complete_setup.sh script with the Keepalived password as an argument.

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
mkdir -p /etc/keepalived
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

### Wait for Keepalived to initialize
# On a BACKUP node, the virtual IP will only be assigned if the MASTER is down.
# Therefore, we verify that Keepalived is running properly rather than checking
# for VIP assignment.
echo "Verifying Keepalived initialization..."
SUCCESS=false
WAIT=1
for i in {1..6}; do
    # Check if Keepalived is running and has initialized VRRP
    if systemctl is-active --quiet keepalived && \
       journalctl -u keepalived -n 50 | grep -q "VRRP_Instance(VI_1)"; then
        echo "Keepalived has initialized successfully."
        SUCCESS=true
        break
    fi
    if [ $i -lt 6 ]; then
        echo "Attempt $i: Keepalived not fully initialized, waiting ${WAIT}s before retry..."
        sleep $WAIT
        WAIT=$((WAIT * 2))  # Double the wait time: 1, 2, 4, 8, 16 seconds.
    fi
done

if [ "$SUCCESS" = false ]; then
    echo "ERROR: Keepalived failed to initialize properly after multiple attempts."
    echo "Check Keepalived logs with: journalctl -u keepalived -n 20"
    exit 1
fi

# Check if this node has the virtual IP (indicates MASTER state or MASTER is down)
if ip addr show "$PRIMARY_INTERFACE" | grep -q "192.168.0.2"; then
    echo "WARNING: Virtual IP 192.168.0.2 is assigned to this BACKUP node."
    echo "This means either:"
    echo "  1. The MASTER node (Ravage) is currently offline, OR"
    echo "  2. There is a configuration issue"
    echo "If Ravage should be online, investigate immediately."
else
    echo "Virtual IP is not assigned (normal for Howlback when Ravage is online)."
fi

### Completion Message
echo ""
echo "=============================================================="
echo "                   Keepalived Setup Complete"
echo "=============================================================="
echo "Node Role: BACKUP"
echo "Virtual IP: 192.168.0.2 (will be assigned if MASTER fails)"
echo "Keepalived is monitoring MASTER at: 192.168.0.250"
echo ""