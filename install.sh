#!/bin/bash

# Function to display a progress bar
progress_bar() {
    local progress=$1
    local total=100
    local done=$((progress * 50 / total))
    local left=$((50 - done))
    fill=$(printf "%${done}s" | tr " " "#")
    empty=$(printf "%${left}s" | tr " " "-")
    printf "\rProgress : [${fill}${empty}] ${progress}%%"
}

# Initialize progress
progress=0
progress_bar $progress

# ==============================
# Step 1: Update system
# ==============================
echo -e "\nUpdating system..."
sudo apt update && sudo apt upgrade -y
progress=10
progress_bar $progress

# ==============================
# Step 2: Install Docker
# ==============================
echo -e "\nInstalling Docker..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
progress=30
progress_bar $progress

# ==============================
# Step 3: Install Docker Compose
# ==============================
echo -e "\nInstalling Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
progress=45
progress_bar $progress

# ==============================
# Step 4: Add user to docker group
# ==============================
sudo usermod -aG docker $USER
progress=50
progress_bar $progress

# ==============================
# Step 5: Create directories
# ==============================
mkdir -p ~/docker/portainer ~/docker/wireguard ~/docker/pihole ~/docker/n8n ~/docker/heimdall ~/docker/yacht
progress=60
progress_bar $progress

# ==============================
# Step 6: Create docker-compose.yml
# ==============================
cat > ~/docker/docker-compose.yml <<'EOF'
version: "3.9"

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "9000:9000"
    volumes:
      - portainer_data:/data
      - /var/run/docker.sock:/var/run/docker.sock

  wireguard:
    image: ghcr.io/linuxserver/wireguard
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Africa/Johannesburg
      - SERVERURL=yourdomain.com
      - SERVERPORT=51820
      - PEERS=1
      - PEERDNS=1.1.1.1
      - INTERNAL_SUBNET=10.13.13.0
    volumes:
      - ./wireguard/config:/config
      - /lib/modules:/lib/modules
    ports:
      - "51820:51820/udp"
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped

  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    environment:
      TZ: Africa/Johannesburg
      WEBPASSWORD: "yourpassword"
      DNS1: 1.1.1.1
      DNS2: 1.0.0.1
    volumes:
      - ./pihole/etc-pihole:/etc/pihole
      - ./pihole/etc-dnsmasq.d:/etc/dnsmasq.d
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
    restart: unless-stopped

  n8n:
    image: n8nio/n8n
    container_name: n8n
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=yourpassword
    volumes:
      - ./n8n:/home/node/.n8n
    restart: unless-stopped

  heimdall:
    image: linuxserver/heimdall
    container_name: heimdall
    ports:
      - "8080:80"
    volumes:
      - ./heimdall/config:/config
    restart: unless-stopped

  yacht:
    image: selfhostedpro/yacht:latest
    container_name: yacht
    ports:
      - "8000:8000"
    volumes:
      - ./yacht/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped

volumes:
  portainer_data:
EOF
progress=75
progress_bar $progress

# ==============================
# Step 7: Start Docker Compose
# ==============================
cd ~/docker
docker-compose up -d
progress=100
progress_bar $progress

echo -e "\nAll containers deployed successfully!"
echo "Portainer: http://localhost:9000"
echo "Heimdall: http://localhost:8080"
echo "Yacht: http://localhost:8000"
echo "n8n: http://localhost:5678"
echo "Pi-hole: port 80"
echo "WireGuard: UDP port 51820"
