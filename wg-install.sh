#!/bin/bash
# WireGuard VPN Auto-Installer for Cloud Bursting Nodes
# Version: 1.2

set -euo pipefail

# Configuration
CONFIG_DIR="/etc/wireguard"
WG_PORT="51820"
WG_NET="10.8.0.0/24"
ON_PREM_IP="192.168.1.100"  # Replace with your on-prem server IP
ON_PREM_PUBKEY=""            # Will be fetched automatically

# Validate input
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Install dependencies
echo "[+] Installing WireGuard..."
apt-get update
apt-get install -y wireguard qrencode resolvconf

# Generate keys
echo "[+] Generating keys..."
umask 077
mkdir -p "$CONFIG_DIR"
wg genkey | tee "$CONFIG_DIR/private.key" >/dev/null
wg pubkey < "$CONFIG_DIR/private.key" | tee "$CONFIG_DIR/public.key" >/dev/null

# Fetch on-prem public key
echo "[+] Retrieving on-prem public key..."
ON_PREM_PUBKEY=$(ssh -o StrictHostKeyChecking=no "$ON_PREM_IP" "cat /etc/wireguard/public.key")

# Generate config
echo "[+] Creating WireGuard configuration..."
PRIVATE_KEY=$(cat "$CONFIG_DIR/private.key")
LOCAL_IP="${WG_NET%.*}.$(hostname -I | awk '{print $1}' | cut -d. -f4)"

cat > "$CONFIG_DIR/wg0.conf" <<EOL
[Interface]
Address = $LOCAL_IP/24
PrivateKey = $PRIVATE_KEY
ListenPort = $WG_PORT
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $ON_PREM_PUBKEY
AllowedIPs = 192.168.1.0/24
Endpoint = $ON_PREM_IP:$WG_PORT
PersistentKeepalive = 25
EOL

# Enable service
echo "[+] Starting WireGuard..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Generate QR code for mobile config
qrencode -t ansiutf8 < "$CONFIG_DIR/wg0.conf"

echo "[+] WireGuard setup complete!"
echo "    Local IP: $LOCAL_IP/24"
echo "    Public Key: $(cat "$CONFIG_DIR/public.key")"
