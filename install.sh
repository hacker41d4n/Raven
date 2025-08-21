#!/bin/bash
# Automatic Raven setup script - Debian-based systems
# Installs Docker, n8n, and WireGuard (wg-easy) with defaults

set -e
export DEBIAN_FRONTEND=noninteractive

# -----------------------
# 1️⃣ Default settings
# -----------------------
TIMEZONE="Europe/London"
WG_HOST="192.168.0.181"
WG_PASSWORD="1298144"

echo "⏳ Using defaults:"
echo "Timezone: $TIMEZONE"
echo "WireGuard Host: $WG_HOST"
echo "WireGuard Password: $WG_PASSWORD"

# -----------------------
# 2️⃣ System update
# -----------------------
sudo apt update -y
sudo apt upgrade -y

# -----------------------
# 3️⃣ Install prerequisites
# -----------------------
sudo apt install -y ca-certificates curl gnupg lsb-release

# -----------------------
# 4️⃣ Install Docker
# -----------------------
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER

# -----------------------
# 5️⃣ Setup n8n
# -----------------------
docker volume create n8n_data

docker run -d \
  --name n8n \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e GENERIC_TIMEZONE="$TIMEZONE" \
  -e TZ="$TIMEZONE" \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -e N8N_RUNNERS_ENABLED=true \
  -e N8N_SECURE_COOKIE=false \
  docker.n8n.io/n8nio/n8n

# -----------------------
# 6️⃣ Setup WireGuard (wg-easy)
# -----------------------
sudo mkdir -p /opt/stacks/wireguard
cd /opt/stacks/wireguard || exit

# Generate password hash
HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$WG_PASSWORD")
echo "✅ Generated WireGuard password hash: $HASH"

# Write docker-compose.yml with correct hash
printf "services:
  wg-easy:
    container_name: wg-easy
    image: ghcr.io/wg-easy/wg-easy

    environment:
    - PASSWORD_HASH: '%s'
    - WG_HOST: '%s'
    - UI_TRAFFIC_STATS=true

    volumes:
      - ./config:/etc/wireguard
      - /lib/modules:/lib/modules

    ports:
      - '51820:51820/udp'
      - '51821:51821/tcp'

    restart: unless-stopped

    cap_add:
      - NET_ADMIN
      - SYS_MODULE

    sysctls:
      net.ipv4.ip_forward: 1
      net.ipv4.conf.all.src_valid_mark: 1
" "$HASH" "$WG_HOST" > docker-compose.yml

# Start WireGuard stack
docker compose down || true
docker compose up -d

echo "🎉 Raven automatic setup complete!"
echo "n8n URL: http://localhost:5678"
echo "WireGuard wg-easy URL: http://$WG_HOST:51821 (login with password: $WG_PASSWORD)"
