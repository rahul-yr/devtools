#!/bin/bash

# ----------- MUST RUN AS ROOT ------------
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run as root. Use sudo or log in as root."
  exit 1
fi

set -e

echo "🔧 Installing system dependencies (Docker, Docker Compose, NGINX, Certbot, UFW)..."

apt update -y
apt install -y ca-certificates curl gnupg lsb-release software-properties-common ufw nginx

# -------- Install Docker if not installed --------
if ! command -v docker &>/dev/null; then
  echo "🐳 Installing Docker..."
  mkdir -m 0755 -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt update -y
  apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable docker
  systemctl start docker
else
  echo "✅ Docker already installed"
fi

# -------- Docker Compose Plugin --------
if ! docker compose version &>/dev/null; then
  echo "🔧 Installing Docker Compose plugin..."
  apt install -y docker-compose-plugin
else
  echo "✅ Docker Compose plugin already available"
fi

# -------- Install Certbot --------
if ! command -v certbot &>/dev/null; then
  echo "🔐 Installing Certbot for HTTPS..."
  apt install -y certbot python3-certbot-nginx
else
  echo "✅ Certbot already installed"
fi

echo "✅ Prerequisites installed. You can now use n8n-deploy.sh to create or delete deployments."
