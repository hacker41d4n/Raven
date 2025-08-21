#!/bin/bash
# Raven setup script

# -----------------------
# System update
# -----------------------
sudo apt update -y
sudo apt upgrade -y

# -----------------------
# Docker install
# -----------------------

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to Docker group
sudo usermod -aG docker $USER

# -----------------------
# n8n install
# -----------------------

# Create Docker volume
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
# WireGuard install
# -----------------------

# Create WireGuard directory
sudo mkdir -p /opt/stacks/wireguard
cd /opt/stacks/wireguard || exit

# Generate password hash
PASSWORD="1298144"
HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$PASSWORD")
echo "✅ Generated password hash: $HASH"

# Create docker-compose.yml
cat <<EOF > docker-compose.yml
version: "3.8"

services:
  wg-easy:
    container_name: wg-easy
    image: ghcr.io/wg-easy/wg-easy

    environment:
      - PASSWORD_HASH="$HASH"
      - WG_HOST=192.168.0.181

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
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
EOF

# Start WireGuard stack
docker compose up -d
