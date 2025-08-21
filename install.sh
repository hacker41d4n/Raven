#Raven

#System update

apt update -y
apt upgrade -y

#Docker install

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# n8n install

docker volume create n8n_data

docker run -it --rm \
 --name n8n \
 -p 5678:5678 \
 -e GENERIC_TIMEZONE="<YOUR_TIMEZONE>" \
 -e TZ="<YOUR_TIMEZONE>" \
 -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
 -e N8N_RUNNERS_ENABLED=true \
 -v n8n_data:/home/node/.n8n \
 docker.n8n.io/n8nio/n8n

# fix cookies error
    docker run -d -it --rm \
    --name n8n \
    -p 5678:5678 \
    -v n8n_data:/home/node/.n8n \
    -e N8N_SECURE_COOKIE=false \
    docker.n8n.io/n8nio/n8n

# Wireguard install

# Add user to docker group (so you don't need sudo for docker)
sudo usermod -aG docker $USER

# Create directory for WireGuard stack
sudo mkdir -p /opt/stacks/wireguard
cd /opt/stacks/wireguard

# Run wg-easy once to generate a password hash (example shown)
docker run --rm -it ghcr.io/wg-easy/wg-easy wgpw '1298144'

# Generate docker-compose.yml
cat <<EOF > docker-compose.yml
version: "3.8"

services:
  wg-easy:
    container_name: wg-easy
    image: ghcr.io/wg-easy/wg-easy

    environment:
      - PASSWORD_HASH= $$2a$$12$$OkDnvHYzk26kEIPAt7j6g.zO6h/FuNzu.UCTNfa84mzD3uJyZR8SG
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

# Start the stack
docker compose up -d