#!/bin/bash


# ----------- CONFIGURE THESE VARIABLES ------------
DOMAIN="n8n.example.com"
EMAIL_FOR_SSL="you@example.com"
N8N_BASIC_AUTH_USER="admin"
N8N_BASIC_AUTH_PASSWORD="VeryStrongPassword123"
N8N_ENCRYPTION_KEY="$(openssl rand -hex 32)"  # keep this safe
N8N_PORT=5678
# --------------------------------------------------

# ----------- MUST RUN AS ROOT ------------
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run as root. Use sudo or log in as root."
  exit 1
fi

# ----------- CHECK PORTS 80/443 ------------
if lsof -i :80 -sTCP:LISTEN -t >/dev/null || lsof -i :443 -sTCP:LISTEN -t >/dev/null; then
  echo "⚠️  Ports 80 or 443 are already in use. NGINX and Certbot require these ports."
  echo "    Please free these ports before running this script."
  exit 1
fi

# ----------- UFW SSH WARNING ------------
if ! ufw status | grep -q OpenSSH; then
  echo "⚠️  UFW is about to be enabled. If you are connected via SSH, make sure OpenSSH is allowed to avoid being locked out."
  echo "    The script will continue in 10 seconds. Press Ctrl+C to abort."
  sleep 10
fi

set -e

echo "🌐 Setting up n8n at https://$DOMAIN..."

# -------- Update system and install dependencies --------
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
fi

# -------- Create n8n folder and docker-compose --------
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
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n-net

networks:
  n8n-net:

volumes:
  n8n_data:
EOF

# -------- Start n8n container --------
docker compose up -d

# -------- Set up NGINX reverse proxy --------
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

# -------- Get HTTPS certificate --------
echo "🔐 Requesting SSL cert from Let's Encrypt..."
if ! certbot --nginx -n --agree-tos --email "$EMAIL_FOR_SSL" -d "$DOMAIN"; then
  echo "❌ Certbot failed to obtain an SSL certificate. Check your domain DNS and try again."
  exit 1
fi

# -------- Enable auto-renewal --------
systemctl enable certbot.timer

# -------- Configure firewall --------
echo "🔥 Configuring UFW firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# -------- Done --------
echo ""
echo "🎉 n8n is ready at: https://$DOMAIN"
echo "n8n_encryption_key: $N8N_ENCRYPTION_KEY"
echo "🔐 Basic Auth: $N8N_BASIC_AUTH_USER / (password hidden)"
echo "🔁 Docker containers auto-restart enabled"
echo "📂 Workflows stored in: Docker volume 'n8n_data'"
echo ""
