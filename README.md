# Knot Resolver LXC Deploy Script

This repository contains an automated deployment script to set up Knot Resolver inside a Proxmox LXC container with DNS forwarding to NextDNS.

## Usage

### Download the script
```bash
curl -O https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/knot-resolver-lxc-deploy/main/knot-deploy.sh
chmod +x knot-deploy.sh
```

### Run the script
```bash
./knot-deploy.sh
```

You will be prompted to enter your Proxmox network bridge name.

## After Deployment

Set your internal network's DNS server to the IP address displayed at the end of the script.
