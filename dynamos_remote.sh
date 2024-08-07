#!/bin/bash

# Ensure the script is run as root
if [[ "$(id -u)" -ne 0 ]]; then
    sudo -E "$0" "$@"
    exit
fi

# Variables
DOMAIN="qurtnex.net.ng"
EMAIL="qurtana93@outlook.com"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
TUNNEL_USER="tunnel"

# Function to print messages
print_message() {
  echo -e "\n>>> $1\n"
}

# Function to check if the SSL certificate is valid
is_cert_valid() {
  if [ -d "$CERT_DIR" ]; then
    CERT_FILE="$CERT_DIR/fullchain.pem"
    if openssl x509 -checkend 86400 -noout -in "$CERT_FILE" > /dev/null; then
      return 0
    fi
  fi
  return 1
}

# Ensure the sudo group exists and has elevated privileges
print_message "Ensuring the sudo group exists and has elevated privileges..."
if ! getent group sudo > /dev/null; then
    groupadd sudo
fi

if ! grep -q "^%sudo" /etc/sudoers; then
    echo "%sudo   ALL=(ALL:ALL) ALL" >> /etc/sudoers
fi

# Create the tunnel user without a password
print_message "Creating the tunnel user without a password..."
adduser --disabled-password --gecos "" $TUNNEL_USER
usermod -aG sudo $TUNNEL_USER
passwd -d $TUNNEL_USER

# Update and install required packages
print_message "Updating package list and installing required packages..."
apt update
apt install -y openssh-server nginx certbot python3-certbot-nginx uuid-runtime

# Configure SSH for reverse forwarding and passwordless tunnel user access
print_message "Configuring SSH..."
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config

# Add configuration for tunnel user
cat >> /etc/ssh/sshd_config <<EOL

# Allow passwordless login for tunnel user
Match User tunnel
    PermitEmptyPasswords yes
    PasswordAuthentication no
    PubkeyAuthentication no
    ChallengeResponseAuthentication no
EOL

# Configure PAM for SSH to allow passwordless tunnel user login
print_message "Configuring PAM for SSH..."
if ! grep -q "auth sufficient pam_permit.so" /etc/pam.d/sshd; then
    echo "auth sufficient pam_permit.so" >> /etc/pam.d/sshd
fi

systemctl restart sshd

# Configure Nginx for wildcard domains
print_message "Configuring Nginx..."
NGINX_CONF="/etc/nginx/sites-available/reverse-proxy"
cat > $NGINX_CONF <<EOL
server {
    listen 80;
    server_name *.$DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name *.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://localhost:\$http_x_forwarded_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

ln -s /etc/nginx/sites-available/reverse-proxy /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Check if SSL certificate exists and is valid
if is_cert_valid; then
  print_message "SSL certificate already exists and is valid."
else
  # Obtain wildcard SSL certificate with Certbot
  print_message "Obtaining SSL certificate with Certbot..."
  print_message "IMPORTANT: You will need to manually add a DNS TXT record for verification."
  certbot certonly --manual --preferred-challenges dns -d "*.$DOMAIN" --agree-tos --no-bootstrap --manual-public-ip-logging-ok --email $EMAIL
  print_message "Follow the Certbot instructions to add the DNS TXT record."
  print_message "After adding the record and it has propagated, press Enter to continue."
fi

# Create the subdomain assignment script
print_message "Creating subdomain assignment script..."
SUBDOMAIN_SCRIPT="/usr/local/bin/assign_subdomain.sh"
cat > $SUBDOMAIN_SCRIPT <<'EOL'
#!/bin/bash

# Generate a unique subdomain
SUBDOMAIN=$(uuidgen | cut -d'-' -f1)
PORT=$1
USER=$2

# Log the subdomain and port mapping (for debugging purposes)
echo "$SUBDOMAIN: localhost:$PORT" >> /var/log/subdomains.log

# Output the subdomain to the user
echo "Your application is available at https://$SUBDOMAIN.yourdomain.com"
EOL

chmod +x /usr/local/bin/assign_subdomain.sh

# Create systemd service for subdomain assignment
print_message "Creating systemd service for subdomain assignment..."
SYSTEMD_SERVICE="/etc/systemd/system/assign-subdomain.service"
cat > $SYSTEMD_SERVICE <<EOL
[Unit]
Description=Assign Subdomain for SSH Reverse Forwarding
After=network.target

[Service]
ExecStart=/usr/local/bin/assign_subdomain.sh %p %u

[Install]
WantedBy=multi-user.target
EOL

systemctl enable assign-subdomain.service

print_message "Setup completed successfully. Test the setup by running the following command from your local machine:"
echo "ssh -R 80:localhost:80 tunnel@$DOMAIN"