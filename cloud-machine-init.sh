#!/bin/sh
set -euo pipefail

# Alpine + WireGuard + Caddy Gateway
# Runs as root on first GCE boot (via user-data)

# Fetch GCE Public IP via Metadata server
GCE_PUBLIC_IP=$(wget -q -O- --header="Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)

# Addressing Parameters
WG_NET="10.20.0.0/24"
WG_GW_IP="10.20.0.1/24"
LOCAL_LAN_SUBNET="192.168.1.0/24"

# Target IP Routing Allocations
LOCAL_PEER_IP="10.20.0.2/32"
LAPTOP_PEER_IP="10.20.0.3/32"

# Allowed Target Services on Local LAN (Explicit Minimum)
N8N_IP="192.168.1.10"
POSTGRES_IP="192.168.1.20"
HA_IP="192.168.1.30"

# Caddy Configuration
CADDY_DOMAIN="${CADDY_DOMAIN:-vpn-gateway.local}"
CADDY_PORT="443"

echo "==> Updating system packages and installing dependencies..."
apk update
apk add --no-cache \
  wireguard-tools \
  wireguard-module \
  nftables \
  iptables \
  openrc \
  curl \
  wget \
  ca-certificates \
  caddy

echo "==> Applying Sysctl Kernel Hardening & IP Forwarding..."
cat <<'EOF' > /etc/sysctl.d/99-wireguard-gateway.conf
net.ipv4.ip_forward = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF
sysctl -p /etc/sysctl.d/99-wireguard-gateway.conf > /dev/null

echo "==> Generating Ephemeral WireGuard Keys (in-memory, ephemeral on reboot)..."
GW_PRIVATE_KEY=$(wg genkey)
GW_PUBLIC_KEY=$(echo "${GW_PRIVATE_KEY}" | wg pubkey)

LOCAL_PEER_PRIVATE_KEY=$(wg genkey)
LOCAL_PEER_PUBLIC_KEY=$(echo "${LOCAL_PEER_PRIVATE_KEY}" | wg pubkey)

LAPTOP_PRIVATE_KEY=$(wg genkey)
LAPTOP_PUBLIC_KEY=$(echo "${LAPTOP_PRIVATE_KEY}" | wg pubkey)

echo "==> Configuring WireGuard Interface (/etc/wireguard/wg0.conf)..."
umask 077
cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address = ${WG_GW_IP}
ListenPort = 51820
PrivateKey = ${GW_PRIVATE_KEY}

# Local LAN Connector Peer
[Peer]
PublicKey = ${LOCAL_PEER_PUBLIC_KEY}
AllowedIPs = ${LOCAL_PEER_IP}, ${LOCAL_LAN_SUBNET}
PersistentKeepalive = 25

# Remote Laptop Administrator Peer
[Peer]
PublicKey = ${LAPTOP_PUBLIC_KEY}
AllowedIPs = ${LAPTOP_PEER_IP}
EOF
chmod 600 /etc/wireguard/wg0.conf

echo "==> Deploying Strict nftables Security Ruleset..."
cat <<EOF > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table ip filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Allow Loopback
        iifname "lo" accept

        # Stateful Inspection
        ct state established,related accept
        ct state invalid drop

        # WireGuard Inbound UDP
        udp dport 51820 accept

        # GCP IAP SSH Access Only
        ip saddr 35.235.240.0/20 tcp dport 22 accept

        # Overlay Ping Diagnostic
        iifname "wg0" icmp type echo-request accept
    }

    chain forward {
        type filter hook forward priority 0; policy drop;

        # Allow Established / Related Traversal
        ct state established,related accept

        # Strict Routing Constraints: WireGuard Overlay -> Specific LAN Targets ONLY
        iifname "wg0" ip saddr ${WG_NET} ip daddr ${N8N_IP} tcp dport 5678 accept
        iifname "wg0" ip saddr ${WG_NET} ip daddr ${POSTGRES_IP} tcp dport 5432 accept
        iifname "wg0" ip saddr ${WG_NET} ip daddr ${HA_IP} tcp dport 8123 accept

        # ICMP across WG Overlay
        iifname "wg0" icmp type echo-request accept
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
chmod 700 /etc/nftables.conf

echo "==> Configuring Caddy Reverse Proxy..."
mkdir -p /etc/caddy /var/www/caddy
cat <<EOF > /etc/caddy/Caddyfile
${CADDY_DOMAIN}:${CADDY_PORT} {
    tls internal

    # Root health check endpoint
    respond / 200 {
        body "WireGuard Gateway Ready"
    }

    # Proxy to internal services (accessible via WireGuard tunnel only)
    reverse_proxy /n8n* ${N8N_IP}:5678
    reverse_proxy /postgres* ${POSTGRES_IP}:5432
    reverse_proxy /ha* ${HA_IP}:8123
}
EOF

echo "==> Starting Services (OpenRC)..."
rc-service nftables start
rc-update add nftables boot

rc-service wg-quick start wg0
rc-update add wg-quick boot

rc-service caddy start
rc-update add caddy boot

# Write server public key to a temp location for post-boot retrieval
echo "${GW_PUBLIC_KEY}" > /tmp/wg0-public.key
chmod 644 /tmp/wg0-public.key

# Clear sensitive local variables
unset GW_PRIVATE_KEY LOCAL_PEER_PRIVATE_KEY LAPTOP_PRIVATE_KEY

echo ""
echo "=================================================================="
echo " WIREGUARD GATEWAY READY"
echo " Public IP: ${GCE_PUBLIC_IP}"
echo " Server Public Key: ${GW_PUBLIC_KEY}"
echo "=================================================================="
echo ""
echo "--- 1. LOCAL LAN PEER CONFIG ---"
cat <<EOF
[Interface]
Address = 10.20.0.2/24
PrivateKey = ${LOCAL_PEER_PRIVATE_KEY}
PostUp = sysctl -w net.ipv4.ip_forward=1; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = ${GW_PUBLIC_KEY}
Endpoint = ${GCE_PUBLIC_IP}:51820
AllowedIPs = 10.20.0.0/24
PersistentKeepalive = 25
EOF

echo ""
echo "--- 2. REMOTE LAPTOP CONFIG ---"
cat <<EOF
[Interface]
Address = 10.20.0.3/32
PrivateKey = ${LAPTOP_PRIVATE_KEY}
DNS = 1.1.1.1

[Peer]
PublicKey = ${GW_PUBLIC_KEY}
Endpoint = ${GCE_PUBLIC_IP}:51820
AllowedIPs = 10.20.0.0/24, 192.168.1.0/24
PersistentKeepalive = 25
EOF
echo "=================================================================="
