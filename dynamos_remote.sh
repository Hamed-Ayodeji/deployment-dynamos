#!/bin/bash

# Ensure the script is run as root
if [[ "$(id -u)" -ne 0 ]]; then
    sudo -E "$0" "$@"
    exit
fi

# Variables
DOMAIN="thequrtbuck.com.ng"
EMAIL="qurtana93@outlook.com"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
TUNNEL_USER="tunnel"
REMOTE_PORT=8080

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
sed -i 's/#AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config

# Add configuration for tunnel user in SSHD config
cat >> /etc/ssh/sshd_config <<EOL

# Allow passwordless login for tunnel user
Match User $TUNNEL_USER
    PermitEmptyPasswords yes
    PasswordAuthentication yes
    ForceCommand /usr/local/bin/auto_setup.sh
    PubkeyAuthentication no
    ChallengeResponseAuthentication no
    GatewayPorts yes
    AllowTcpForwarding yes
EOL

# Configure PAM for SSH to allow passwordless tunnel user login
print_message "Configuring PAM for SSH..."
if ! grep -q "auth sufficient pam_permit.so" /etc/pam.d/sshd; then
    echo "auth sufficient pam_permit.so" >> /etc/pam.d/sshd
fi

# Restart SSH service to apply changes
systemctl restart ssh

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

# Remove the default Nginx configuration
print_message "Removing the default Nginx configuration..."
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

# Create the configure_nginx.sh script
print_message "Creating the configure_nginx.sh script..."
CONFIGURE_NGINX_SCRIPT="/usr/local/bin/configure_nginx.sh"
cat > $CONFIGURE_NGINX_SCRIPT <<'EOF'
#!/bin/bash

REMOTE_PORT=8080
SUBDOMAIN=$1
DOMAIN="thequrtbuck.com.ng"

# Check if SUBDOMAIN is provided
if [[ -z "$SUBDOMAIN" ]]; then
    echo "Subdomain not specified"
    exit 1
fi

# Configure Nginx for the unique subdomain
NGINX_CONF="/etc/nginx/sites-available/$SUBDOMAIN"
if [ -f $NGINX_CONF ]; then
    rm $NGINX_CONF
fi

cat > $NGINX_CONF <<EOL
server {
    listen 80;
    server_name $SUBDOMAIN.$DOMAIN;
    location / {
        proxy_pass http://localhost:$REMOTE_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 443 ssl;
    server_name $SUBDOMAIN.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://localhost:$REMOTE_PORT;
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
EOF

chmod +x /usr/local/bin/configure_nginx.sh

# Create the auto_setup.sh script
print_message "Creating the auto setup script..."
AUTO_SETUP_SCRIPT="/usr/local/bin/auto_setup.sh"
cat > $AUTO_SETUP_SCRIPT <<'EOF'
#!/bin/bash

# Debug information
exec > >(tee -a /home/tunnel/debug.log) 2>&1

# Set the remote port permanently to 8080
REMOTE_PORT=8080

# Generate a unique subdomain
SUBDOMAIN=$(uuidgen | cut -d'-' -f1)

# Configure forwarding from the remote port and set up Nginx
{
    sudo /usr/local/bin/configure_nginx.sh $SUBDOMAIN
} &> /dev/null  # Suppresses the output of the configuration steps

# Display the public URL
printf "\n%-20s %-40s\n" "Public URL" | tee -a /home/tunnel/debug.log
printf "%-20s %-40s\n" "----------" | tee -a /home/tunnel/debug.log
printf "%-20s %-40s\n" "https://$SUBDOMAIN.thequrtbuck.com.ng" | tee -a /home/tunnel/debug.log

echo "Setup completed successfully." | tee -a /home/tunnel/debug.log

# Keep the session open for debugging
echo "Press [CTRL+C] to exit" | tee -a /home/tunnel/debug.log
tail -f /dev/null
EOF

chmod +x /usr/local/bin/auto_setup.sh

# Create a sudoers file for the tunnel user
print_message "Creating sudoers file for tunnel user..."
SUDOERS_FILE="/etc/sudoers.d/tunnel"
cat > $SUDOERS_FILE <<EOF
tunnel ALL=(ALL) NOPASSWD: /usr/local/bin/configure_nginx.sh
EOF

# Restart Nginx to apply changes
print_message "Restarting Nginx to apply changes..."
systemctl restart nginx

print_message "Setup completed successfully. To use the setup, run the following SSH command from your local machine:"
echo "ssh -R 8080:localhost:<local_port> tunnel@$DOMAIN"
