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

# Create the tunnel user without a password
print_message "Creating the tunnel user without a password..."
if ! id -u $TUNNEL_USER > /dev/null 2>&1; then
    adduser --disabled-password --gecos "" $TUNNEL_USER
    passwd -d $TUNNEL_USER
else
    print_message "User $TUNNEL_USER already exists."
fi

# Update and install required packages
print_message "Updating package list and installing required packages..."
apt update && apt install -y openssh-server nginx certbot python3-certbot-nginx uuid-runtime

# Configure SSH for reverse forwarding and passwordless tunnel user access
print_message "Configuring SSH..."
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config

# Add configuration for tunnel user
cat >> /etc/ssh/sshd_config <<EOL

# Allow passwordless login for tunnel user
Match User $TUNNEL_USER
    PermitEmptyPasswords yes
    PasswordAuthentication yes
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
if [ -f $NGINX_CONF ]; then
    rm $NGINX_CONF
fi
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

if [ -L /etc/nginx/sites-enabled/reverse-proxy ]; then
    rm /etc/nginx/sites-enabled/reverse-proxy
fi
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

# Create the configure_nginx.sh script
print_message "Creating the configure_nginx.sh script..."
CONFIGURE_NGINX_SCRIPT="/usr/local/bin/configure_nginx.sh"
cat > $CONFIGURE_NGINX_SCRIPT <<'EOL'
#!/bin/bash

LOCAL_PORT=$1
SUBDOMAIN=$2
DOMAIN="qurtnex.net.ng"

# Configure Nginx for the unique subdomain
NGINX_CONF="/etc/nginx/sites-available/$SUBDOMAIN"
if [ -f $NGINX_CONF ]; then
    rm $NGINX_CONF
fi
cat > $NGINX_CONF <<EOL
server {
    listen 80;
    server_name $SUBDOMAIN.$DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $SUBDOMAIN.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://localhost:$LOCAL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

if [ -L /etc/nginx/sites-enabled/$SUBDOMAIN ]; then
    rm /etc/nginx/sites-enabled/$SUBDOMAIN
fi
ln -s /etc/nginx/sites-available/$SUBDOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
EOL

chmod +x /usr/local/bin/configure_nginx.sh

# Create the auto_setup.sh script
print_message "Creating the auto setup script..."
AUTO_SETUP_SCRIPT="/usr/local/bin/auto_setup.sh"
cat > $AUTO_SETUP_SCRIPT <<'EOL'
#!/bin/bash

# Extract the remote port, host, and local port from the SSH_ORIGINAL_COMMAND
if [[ -n "$SSH_ORIGINAL_COMMAND" ]]; then
  REMOTE_PORT=$(echo $SSH_ORIGINAL_COMMAND | sed -n 's/.*-R \([0-9]*\):.*/\1/p')
  HOST=$(echo $SSH_ORIGINAL_COMMAND | sed -n 's/.*-R [0-9]*:\([^:]*\):.*/\1/p')
  LOCAL_PORT=$(echo $SSH_ORIGINAL_COMMAND | sed -n 's/.*-R [0-9]*:[^:]*:\([0-9]*\).*/\1/p')

  if [[ -z $REMOTE_PORT || -z $HOST || -z $LOCAL_PORT ]]; then
    echo "Failed to parse remote port, host, or local port from the SSH command."
    exit 1
  fi

  # Generate a unique subdomain
  SUBDOMAIN=$(uuidgen | cut -d'-' -f1)

  # Configure forwarding from the remote port to the local port and set up Nginx
  echo "Configuring port forwarding from $REMOTE_PORT to $LOCAL_PORT with subdomain $SUBDOMAIN..."
  sudo /usr/local/bin/configure_nginx.sh $LOCAL_PORT $SUBDOMAIN

  LOCAL_URL="http://$HOST:$LOCAL_PORT"
  PUBLIC_URL="https://$SUBDOMAIN.qurtnex.net.ng"

  # Display the URLs in a tabular format
  printf "\n%-20s %-40s\n" "Local URL" "Public URL"
  printf "%-20s %-40s\n" "---------" "----------"
  printf "%-20s %-40s\n" "$LOCAL_URL" "$PUBLIC_URL"

  echo "Setup completed successfully."
else
  echo "This script should be run automatically on SSH login."
fi
EOL

chmod +x /usr/local/bin/auto_setup.sh

# Create a sudoers file for the tunnel user
print_message "Creating sudoers file for tunnel user..."
SUDOERS_FILE="/etc/sudoers.d/tunnel"
cat > $SUDOERS_FILE <<EOL
tunnel ALL=(ALL) NOPASSWD: /usr/local/bin/configure_nginx.sh
EOL

# Add the auto_setup.sh script execution to the tunnel user's .bashrc
print_message "Adding auto setup script execution to the tunnel user's .bashrc..."
BASHRC_FILE="/home/$TUNNEL_USER/.bashrc"
if ! grep -q "/usr/local/bin/auto_setup.sh" "$BASHRC_FILE"; then
  echo 'if [[ -n "$SSH_ORIGINAL_COMMAND" ]]; then /usr/local/bin/auto_setup.sh; fi' >> "$BASHRC_FILE"
fi

print_message "Setup completed successfully. To use the setup, run the following SSH command from your local machine:"
echo "ssh -R <remote_port>:<host>:<local_port> tunnel@$DOMAIN"
