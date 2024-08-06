#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Variables
SSH_USER="ubuntu"              # Default SSH username for Ubuntu on AWS
SSH_DOMAIN="your-domain.com"   # Replace with your domain
NGINX_CONF_DIR="/etc/nginx/sites-available"
NGINX_SITES_ENABLED_DIR="/etc/nginx/sites-enabled"
PUBLIC_PORT=80                 # The public port to be used for forwarding (default to 80)

# Update and install necessary packages
sudo apt update
sudo apt install -y openssh-server nginx ufw

# Configure UFW (Uncomplicated Firewall)
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable

# Configure SSHD
sudo tee -a /etc/ssh/sshd_config > /dev/null <<EOL
# Allow TCP forwarding
AllowTcpForwarding yes

# Allow Gateway ports
GatewayPorts yes

# Disable PAM authentication
UsePAM no
EOL

# Restart SSH service
sudo systemctl restart ssh


# Generate SSH Key Pair (if not already generated)
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "your-email@example.com"
fi

# Copy the Public Key to the Server
ssh-copy-id ${SSH_USER}@${SSH_DOMAIN}

# Function to configure Nginx for a new application
configure_nginx() {
    local app_name=$1
    local local_port=$2
    local subdomain=$3

    sudo tee ${NGINX_CONF_DIR}/${app_name} > /dev/null <<EOL
server {
    listen ${PUBLIC_PORT};

    server_name ${subdomain}.${SSH_DOMAIN};

    location / {
        proxy_pass http://localhost:${local_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

    sudo ln -s ${NGINX_CONF_DIR}/${app_name} ${NGINX_SITES_ENABLED_DIR}/${app_name}
}

# Restart Nginx service
sudo systemctl restart nginx


# Provide instructions for SSH reverse forwarding
echo "Setup complete! To use the tunneling service, follow these steps:"
echo "1. Ensure your local application is running on the desired local port (e.g., 3000)."
echo "2. Run the following command from your local machine:"
echo "   ssh -R <public_port>:localhost:<local_port> ${SSH_USER}@${SSH_DOMAIN}"
echo "   For example: ssh -R 80:localhost:3000 ${SSH_USER}@${SSH_DOMAIN}"
echo "3. Your application will be accessible at http://${SSH_DOMAIN} (or a subdomain if configured)."
