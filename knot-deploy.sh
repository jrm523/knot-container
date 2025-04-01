#!/bin/bash

# Knot Resolver LXC Deploy Script (Proxmox) with NextDNS Forwarding

set -e

# Variables
CTID=110
HOSTNAME="knot"
MEMORY=512
DISK=4
CPU=1
TEMPLATE_STORAGE="local"
ROOTFS_STORAGE="local-lvm"
NEXTDNS_IPV4_1="45.90.28.0"
NEXTDNS_IPV4_2="45.90.30.0"

# Prompt for Network Bridge
read -p "Enter Proxmox network bridge (e.g., vmbr0, vmbr1): " BRIDGE
if [ -z "$BRIDGE" ]; then
  echo "No bridge specified. Exiting."
  exit 1
fi

# Get latest Debian template
echo "Fetching latest Debian template..."
pveam update
TEMPLATE=$(pveam available | grep debian-12-standard | sort -r | head -n 1 | awk '{print $2}')

if [ -z "$TEMPLATE" ]; then
  echo "No Debian template found. Exiting."
  exit 1
fi

# Download template if not already present
if [ ! -f "/var/lib/vz/template/cache/$TEMPLATE" ]; then
  echo "Downloading $TEMPLATE..."
  pveam download $TEMPLATE_STORAGE $TEMPLATE
  echo "Template download complete."
fi

# Create the container
pct create $CTID \
  $TEMPLATE_STORAGE:vztmpl/$TEMPLATE \
  -hostname $HOSTNAME \
  -memory $MEMORY \
  -cores $CPU \
  -net0 name=eth0,bridge=$BRIDGE,firewall=1 \
  -rootfs $ROOTFS_STORAGE:$DISK \
  -password knot123 \
  -unprivileged 1

# Start the container
pct start $CTID

# Wait for network to be ready
echo "Waiting for container network to come up..."
for i in {1..20}; do
  pct exec $CTID -- ping -c 1 1.1.1.1 > /dev/null 2>&1 && break
  echo "Waiting for network (\$i)..."
  sleep 2
done

# Inject DNS resolver
pct exec $CTID -- bash -c "echo 'nameserver 1.1.1.1' > /etc/resolv.conf"

# Install Knot Resolver
pct exec $CTID -- bash -c "apt update && apt upgrade -y"
pct exec $CTID -- bash -c "apt install -y knot-resolver"

# Configure kresd
pct exec $CTID -- bash -c "cat <<EOF > /etc/knot-resolver/kresd.conf
net.listen('0.0.0.0', 53)

policy.add(policy.all(policy.FORWARD('$NEXTDNS_IPV4_1', '$NEXTDNS_IPV4_2')))

cache.size = 100 * MB
EOF"

# Enable and start kresd
pct exec $CTID -- systemctl enable kresd
pct exec $CTID -- systemctl start kresd

# Get container IP
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
echo "\n🎯 Knot Resolver deployed! Set your LAN DNS to: $IP"

