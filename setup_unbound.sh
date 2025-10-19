#!/bin/bash

# FILE: setup_unbound.sh
# DESCRIPTION: A script to install and configure Unbound as a fully recursive DNS resolver
# with security and privacy hardening. 
# This script is designed to be called from the main setup_all.sh script.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Setting up Unbound DNS resolver..."

### Download Root Hints
# This file is essential for Unbound to resolve top-level domains from the root servers.
echo "Downloading root hints file..."
wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root
if [ ! -s /var/lib/unbound/root.hints ]; then
    echo "ERROR: Failed to download root.hints"
    exit 1
fi

### Create the Unbound configuration file
# This creates a minimal configuration that runs Unbound in fully recursive mode.
# Port 5353 is used to avoid conflicts with Pi-hole, which will listen on port 53.
echo "Creating Unbound configuration file..."
cat > /etc/unbound/unbound.conf << EOF
server:
    # Use the local interface and a non-standard port to avoid conflicts with Pi-hole.
    interface: 127.0.0.1
    port: 5353
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    do-ip6: no
    # Only allow local connections, as Unbound will be used by Pi-hole.
    access-control: 127.0.0.1/32 allow
    # Force full recursion.
    do-recursion: yes
    do-not-query-address: 127.0.0.1
    do-not-query-address: ::1
    root-hints: "/var/lib/unbound/root.hints"
    # Set verbosity level to minimal.
    verbosity: 0

    ### Security Settings
    # Enable DNSSEC validation to ensure authenticity of DNS responses,
    # and applies other hardening settings.
    # Ensure Unbound operates in a secure mode.
    harden-glue: yes
    harden-dnssec-stripped: yes
    # Don't use capitalisation randomization as it known to cause DNSSEC issues sometimes
    # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
    use-caps-for-id: no
    # Enable aggressive NSEC handling to improve security.
    aggressive-nsec: yes
    # Prevents resolving subdomains of a non-existent domain.
    harden-below-nxdomain: yes
    # Protect against buffer overflows from malformed queries.
    harden-heap-buffers: yes
    harden-large-queries: yes
    # Set a threshold for dropped forged replies before dropping all
    # traffic from an IP. This mitigates cache poisoning attacks by 
    # aggressively dropping unwanted replies.
    unwanted-reply-threshold: 10000000
    # Minimum TTL for cache entries (in seconds). Prevents excessive 
    # queries for records with very short (e.g., 0-second) TTLs, 
    # reducing upstream load.
    cache-min-ttl: 60
    # Maximum TTL for cache entries (in seconds). Prevents records 
    # with excessively long TTLs from staying in the cache for too long,
    # mitigating prolonged effect of a cache poisoning event.
    cache-max-ttl: 86400
    # Deny resolving these private address ranges to public names.
    # This mitigates DNS Rebinding attacks by ensuring that private 
    # IPs (like 192.168.x.x) cannot be resolved from public DNS names.
    private-address: 192.168.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: 169.254.0.0/16
    private-address: fd00::/8
    private-address: fe80::/10

    ### Privacy Settings
    # Prevents Unbound from revealing its identity or version.
    hide-identity: yes
    hide-version: yes
    # Implements QNAME minimisation to enhance privacy.
    qname-minimisation: yes
    # Do not log queries.
    log-queries: no

    ### Performance Settings
    # Use all available cores for concurrent query processing.
    num-threads: 4
    # Allow multiple threads to listen on the same UDP/TCP port.
    so-reuseport: yes
    # The number of file descriptor slabs should be a power of 2 near
    # num-threads to prevent lock contention.
    msg-cache-slabs: 4
    rrset-cache-slabs: 4
    infra-cache-slabs: 4
    key-cache-slabs: 4
    # Significantly increase cache sizes to utilize 8GB of RAM.
    # rrset-cache-size is typically set to twice the msg-cache-size.
    # These settings provide approximately 768MB of dedicated cache memory.
    msg-cache-size: 256m
    rrset-cache-size: 512m
    # Increase the number of concurrent queries and outgoing sockets per thread.
    # Large values require higher system file descriptor limits,
    # default is often 1024 total.
    outgoing-range: 4096
    num-queries-per-thread: 2048
    # Set socket buffer sizes to handle high loads and traffic spikes.
    so-rcvbuf: 4m
    so-sndbuf: 4m
    # Pre-emptively fetch expriring cache entries and DNSSEC key (DNSKEY) records 
    # to keep popular entries primed.
    prefetch: yes
    prefetch-key: yes
    # Prevent a single client from overwhelming the server with queries.
    # Adjust this value based on your needs.
    ip-ratelimit: 100

    ### Logging Settings
    use-syslog: yes
EOF

### Enable and Start Unbound
# This ensures that Unbound starts automatically on boot.
echo "Enabling and starting Unbound service..."
systemctl enable unbound
systemctl start unbound

### Test Unbound
# We use 'dig' to query a well-known domain.
echo "Testing Unbound DNS resolver..."
dig @127.0.0.1 -p 5353 google.com > /dev/null
# The `if` statement checks the exit status of the previous command.
if [ $? -eq 0 ]; then
    echo "Unbound is working correctly."
else
    echo "ERROR: Unbound test failed. Check the logs for unbound."
    # The script will exit with an error code, which is good practice.
    exit 1
fi

### Completion Message
echo ""
echo "=============================================================="
echo "                     Unbound Setup Complete"
echo "=============================================================="
echo ""
