#!/bin/bash

# Usage: ./n8n-deploy.sh [create|delete]

set -e

# ----------- CONFIGURE THESE VARIABLES ------------
DOMAIN="n8n.example.com"
EMAIL_FOR_SSL="you@example.com"
N8N_BASIC_AUTH_USER="admin"
N8N_BASIC_AUTH_PASSWORD="VeryStrongPassword123"
N8N_ENCRYPTION_KEY="$(openssl rand -hex 32)"  # keep this safe
N8N_PORT=5678
# --------------------------------------------------

ACTION="$1"
if [ -z "$ACTION" ]; then
  echo "Usage: $0 [create|delete]"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run as root. Use sudo or log in as root."
  exit 1
fi

if [ "$ACTION" = "create" ]; then
  # Check ports: only block if something other than nginx is using 80/443
  port_blocker=$(lsof -i :80 -sTCP:LISTEN -t | xargs -r ps -o comm= -p | grep -v nginx || true)
  port_blocker2=$(lsof -i :443 -sTCP:LISTEN -t | xargs -r ps -o comm= -p | grep -v nginx || true)
  if [ -n "$port_blocker" ] || [ -n "$port_blocker2" ]; then
    echo "⚠️  Ports 80 or 443 are already in use by another process (not nginx). NGINX and Certbot require these ports."
    echo "    Please free these ports before running this script."
    lsof -i :80 -i :443
    exit 1
  fi

  # UFW SSH warning
  if ! ufw status | grep -q OpenSSH; then
    echo "⚠️  UFW is about to be enabled. If you are connected via SSH, make sure OpenSSH is allowed to avoid being locked out."
    echo "    The script will continue in 10 seconds. Press Ctrl+C to abort."
    sleep 10
  fi

  echo "🌐 Setting up n8n at https://$DOMAIN..."

  mkdir -p /opt/n8n && cd /opt/n8n
  docker volume create n8n_data >/dev/null 2>&1 || true

  cat <<EOF > docker-compose.yml
version: "3.8"

services:
  n8n:
    image: n8nio/n8n
    restart: unless-stopped
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=$N8N_BASIC_AUTH_USER
      - N8N_BASIC_AUTH_PASSWORD=$N8N_BASIC_AUTH_PASSWORD
      - N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
      - N8N_HOST=$DOMAIN
      - N8N_PORT=$N8N_PORT
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://$DOMAIN/
      - TZ=UTC
      - N8N_RUNNERS_ENABLED=true
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-net

networks:
  n8n-net:

volumes:
  n8n_data:
EOF

  docker compose up -d

  # NGINX reverse proxy
  cat <<EOF > /etc/nginx/sites-available/n8n
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$N8N_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
  nginx -t && systemctl reload nginx

  # SSL
  echo "🔐 Requesting SSL cert from Let's Encrypt..."
  if ! certbot --nginx -n --agree-tos --email "$EMAIL_FOR_SSL" -d "$DOMAIN"; then
    echo "❌ Certbot failed to obtain an SSL certificate. Check your domain DNS and try again."
    exit 1
  fi

  systemctl enable certbot.timer

  # Firewall
  echo "🔥 Configuring UFW firewall..."
  ufw allow OpenSSH
  ufw allow 'Nginx Full'
  ufw --force enable

  echo ""
  echo "🎉 n8n is ready at: https://$DOMAIN"
  echo "n8n_encryption_key: $N8N_ENCRYPTION_KEY"
  echo "🔐 Basic Auth: $N8N_BASIC_AUTH_USER / (password hidden)"
  echo "🔁 Docker containers auto-restart enabled"
  echo "📂 Workflows stored in: Docker volume 'n8n_data'"
  echo ""

elif [ "$ACTION" = "delete" ]; then
  echo "🗑️  Deleting n8n deployment..."
  cd /opt/n8n || { echo "n8n deployment not found."; exit 1; }
  docker compose down -v
  docker volume rm n8n_data || true
  rm -f /opt/n8n/docker-compose.yml
  rm -f /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
  nginx -t && systemctl reload nginx
  echo "n8n deployment deleted."
else
  echo "Unknown action: $ACTION"
  echo "Usage: $0 [create|delete]"
  exit 1
fi
