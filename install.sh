#!/bin/bash
# Raven full setup script
# Works for Debian-based systems

set -e  # Exit on any error
export DEBIAN_FRONTEND=noninteractive

# -----------------------
# 1️⃣ System update
# -----------------------
sudo apt update -y
sudo apt upgrade -y

# -----------------------
# 2️⃣ Install prerequisites for Docker
# -----------------------
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# -----------------------
# 3️⃣ Install Docker
# -----------------------
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to Docker group (no need to log out manually in this script)
sudo usermod -aG docker $USER

# -----------------------
# 4️⃣ Setup n8n
# -----------------------

# Create volume
docker volume create n8n_data

# Run n8n container
docker run -d \
  --name n8n \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e GENERIC_TIMEZONE="Europe/London" \
  -e TZ="Europe/London" \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -e N8N_RUNNERS_ENABLED=true \
  -e N8N_SECURE_COOKIE=false \
  docker.n8n.io/n8nio/n8n

# -----------------------
# 5️⃣ Setup WireGuard (wg-easy)
# -----------------------

# Create stack directory
sudo mkdir -p /opt/stacks/wireguard
cd /opt/stacks/wireguard || exit

# Generate password hash
PASSWORD="1298144"
HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$PASSWORD")
echo "✅ Generated password hash: $HASH"

# Create docker-compose.yml with correct syntax
cat <<EOF > docker-compose.yml
services:
  wg-easy:
    container_name: wg-easy
    image: ghcr.io/wg-easy/wg-easy

    environment:
      PASSWORD_HASH: "$HASH"
      WG_HOST: "192.168.0.181"

    volumes:
      - ./config:/etc/wireguard
      - /lib/modules:/lib/modules

    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"

    restart: unless-stopped

    cap_add:
      - NET_ADMIN
      - SYS_MODULE

    sysctls:
      net.ipv4.ip_forward: 1
      net.ipv4.conf.all.src_valid_mark: 1
EOF

# Start WireGuard stack
docker compose up -d

echo "🎉 Raven setup complete!"
echo "n8n URL: http://localhost:5678"
echo "WireGuard wg-easy URL: http://<WG_HOST>:51821 (login with password you set)"
