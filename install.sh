#!/bin/bash
# Interactive Raven setup script - Debian-based systems
# Installs Docker, n8n, and WireGuard (wg-easy) with user input

set -e
export DEBIAN_FRONTEND=noninteractive

# -----------------------
# 1️⃣ Ask user for input
# -----------------------
read -p "Enter your timezone (e.g., Europe/London): " TIMEZONE
TIMEZONE=${TIMEZONE:-"Europe/London"}

read -p "Enter your WireGuard host IP (e.g., 192.168.0.181): " WG_HOST
WG_HOST=${WG_HOST:-"192.168.0.181"}

read -s -p "Enter your WireGuard password: " PASSWORD
echo

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
# Set installation directory
INSTALL_DIR="/opt/stacks/wireguard"

# Create directory if it doesn't exist
sudo mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit

# Prompt for a password
read -s -p "Enter password for wg-easy: " WG_PASSWORD
echo

# Generate bcrypt hash using Docker (wg-easy provides a utility)
HASH=$(docker run --rm -it ghcr.io/wg-easy/wg-easy wgpw "$WG_PASSWORD")

# Create docker-compose.yml with proper YAML formatting
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy
    container_name: wg-easy
    environment:
      - PASSWORD_HASH="$HASH"
    ports:
      - "51820:51820/udp"
    volumes:
      - ./config:/etc/wg-easy
    restart: unless-stopped
EOF

# Add current user to docker group (so docker can run without sudo)
sudo usermod -aG docker $USER

# Start the container
docker-compose up -d

echo "wg-easy installed and running! Use the password you entered to log in."

# Start WireGuard stack
docker compose down || true
docker compose up -d

echo "🎉 Raven setup complete!"
echo "n8n URL: http://localhost:5678"
echo "WireGuard wg-easy URL: http://$WG_HOST:51821 (login with the password you set)"
