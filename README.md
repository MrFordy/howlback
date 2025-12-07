# Howlback - Automated Pi-hole High Availability Setup (Secondary)
This repository contains scripts to build Howlback, the secondary Pi-hole server with:

Pi-hole - Network-wide ad blocking
Unbound - Fully recursive DNS resolver (no third-party DNS)
Keepalived - High availability with automatic failover

Manual scripts to enable and disable dhcp if required.

This approach was heavily influenced by WunderTech's Ultimate Pi-hole Setup (https://www.wundertech.net/ultimate-pi-hole-setup/) and a desire to make this as simple as reasonably practicable to restore.

See https://github.com/MrFordy/ravage for the primary Pi-hole set up.