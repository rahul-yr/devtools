#!/bin/sh

# Update the variables below to match your environment
DOMAIN_NAME=""
SUPPORT_EMAIL=""
VSCODE_LOGIN_PASSWORD="admin"
USING_GOOGLE_DNS=true
USERNAME=""
PASSWORD=""

# script starts here

# update packages
echo "+ Updating packages..."
sudo apt update

# install code-server from offical repository
echo "+ Installing code-server..."
curl -fsSL https://code-server.dev/install.sh | sh

# create a startup service
echo "+ Creating a startup service..."
sudo systemctl enable --now code-server@$USER

# wait for the service to start
echo "+ Waiting for the service to start..."
sleep 5

# create a script to update the password
echo "+ Updating a script to add the new password..."
sudo sed -i '/password:/d' ~/.config/code-server/config.yaml
sudo echo 'password: '$VSCODE_LOGIN_PASSWORD >> ~/.config/code-server/config.yaml

# restart code-server
echo "+ Restarting code-server..."
sudo systemctl restart code-server@$USER

# install the required packages
echo "+ Installing the required packages for ssl..."
sudo apt install -y nginx certbot python3-certbot-nginx

# create a nginx config file
echo "+ Creating a nginx config file..."
sudo touch /etc/nginx/sites-available/code-server && sudo chmod 777 /etc/nginx/sites-available/code-server

sudo echo '
server {
        listen 80;
        listen [::]:80;
        server_name '${DOMAIN_NAME}';

        location / {
                proxy_pass http://localhost:8080/;
                proxy_set_header Host $host;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection upgrade;
                proxy_set_header Accept-Encoding gzip;
                }
        }
' > /etc/nginx/sites-available/code-server


# link nginx file
sudo ln -sf /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/code-server

# test the nginx configuration
echo "+ Testing the nginx configuration..."
sudo nginx -t

# using google dns
if [ $USING_GOOGLE_DNS = true ]; then
  # create a script to update the dynamic dns
  echo "+ Creating a script to update the dynamic dns using http method..."
  sudo touch /home/update-dynamic-dns.sh && sudo chmod 777 /home/update-dynamic-dns.sh
  
  sudo echo '#!/bin/sh

  # Resolve current public IP
  IP=$(curl -s "https://domains.google.com/checkip")
  # Update Google DNS Record
  URL="https://'${USERNAME}':'${PASSWORD}'@domains.google.com/nic/update?hostname='${DOMAIN_NAME}'&myip=${IP}"
  curl -s $URL
  ' > /home/update-dynamic-dns.sh

  # create a systemd service to update the dynamic dns
  echo "+ Creating a systemd service to update the dynamic dns..."
  sudo touch /etc/systemd/system/update-dynamic-dns.service && sudo chmod 777 /etc/systemd/system/update-dynamic-dns.service

  sudo echo "
  [Unit]
  Description=Update dynamic dns in Google Domains
  After=network.target

  [Service]
  ExecStart=/bin/bash /home/update-dynamic-dns.sh
  Restart=always
  RestartSec=300s
  
  [Install]
  WantedBy=default.target" > /etc/systemd/system/update-dynamic-dns.service

  # start the service
  echo "+ Starting the service..."
  sudo systemctl enable --now update-dynamic-dns.service

fi

# add let's encrpt certificate
echo "+ Adding let's encrypt certificate..."
sudo certbot --non-interactive --redirect --agree-tos --nginx -d ${DOMAIN_NAME} -m ${SUPPORT_EMAIL}

# restart nginx 
echo "+ Restarting nginx..."
sudo systemctl restart nginx

# visit the site
echo "+ Congratulations! You have successfully installed code-server with Nginx."
echo "+ Also you have successfully installed Let's Encrypt certificate."
echo "+ As well as successfully scheduled the dynamic dns service."
echo "+ Visit the site at https://${DOMAIN_NAME}"
echo "##############################################################################"
echo ""
echo "Need help? Available on"
echo "Mail : rahul.mso@outlook.com"
echo "Github : https://github.com/rahul-yr"
echo "Linkedin : https://www.linkedin.com/in/rahul-reddy-y/"
echo ""
echo "##############################################################################"
