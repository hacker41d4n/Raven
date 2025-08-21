#!/usr/bin/env python3

import os
import subprocess
import sys

def run(command):
    """Run a shell command and exit if it fails"""
    print(f"Running: {command}")
    result = subprocess.run(command, shell=True)
    if result.returncode != 0:
        print(f"Error running: {command}")
        sys.exit(1)

def install_dependencies():
    run("sudo apt update && sudo apt upgrade -y")
    run("sudo apt install -y curl gnupg lsb-release software-properties-common")

def install_docker():
    run("curl -fsSL https://get.docker.com -o get-docker.sh")
    run("sh get-docker.sh")
    run("sudo usermod -aG docker $USER")
    run("docker --version")
    run("rm get-docker.sh")

def install_docker_compose():
    # Use latest Compose version
    run("sudo curl -L 'https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)' -o /usr/local/bin/docker-compose")
    run("sudo chmod +x /usr/local/bin/docker-compose")
    run("docker-compose --version")

def setup_wireguard():
    os.makedirs("/opt/wireguard", exist_ok=True)
    os.chdir("/opt/wireguard")
    
    docker_compose_content = """
version: '3.8'
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy
    environment:
      - PASSWORD=1298144
      - WG_HOST=localhost
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    volumes:
      - ./config:/etc/wireguard
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    """
    with open("docker-compose.yml", "w") as f:
        f.write(docker_compose_content)
    
    run("docker-compose up -d")

def setup_n8n():
    os.makedirs("/opt/n8n", exist_ok=True)
    os.chdir("/opt/n8n")
    
    docker_compose_content = """
version: '3'
services:
  n8n:
    image: n8nio/n8n
    container_name: n8n
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=1298144
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - WEBHOOK_TUNNEL_URL=http://localhost:5678/
    volumes:
      - ./n8n:/home/node/.n8n
    restart: unless-stopped
    """
    with open("docker-compose.yml", "w") as f:
        f.write(docker_compose_content)
    
    run("docker-compose up -d")

def main():
    install_dependencies()
    install_docker()
    install_docker_compose()
    setup_wireguard()
    setup_n8n()
    print("Installation complete! Reboot recommended.")

if __name__ == "__main__":
    main()
