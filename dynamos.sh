#!/bin/bash

# Ensure the script is run with root privileges
if [[ "$(id -u)" -ne 0 ]]; then
    sudo -E "$0" "$@"
    exit
fi

log_info() {
    logger -t dynamos.sh "$1"
    echo "$1"
}

# Update package lists and install necessary packages
log_info "Updating package lists..."
apt update

log_info "Installing openssh-server, nginx, certbot, python3-certbot-dns-cloudflare, and whois..."
yes | apt install -y openssh-server nginx certbot python3-certbot-dns-cloudflare whois

# Enable and start SSH service
log_info "Enabling and starting SSH service..."
systemctl enable ssh
systemctl start ssh

# Configure SSH to allow gateway ports for reverse forwarding and use PAM
log_info "Configuring SSH for gateway ports, TCP forwarding, and PAM..."
sed -i '/^#GatewayPorts no/c\GatewayPorts yes' /etc/ssh/sshd_config
sed -i '/^#AllowTcpForwarding yes/c\AllowTcpForwarding yes' /etc/ssh/sshd_config
sed -i '/^#UsePAM yes/c\UsePAM yes' /etc/ssh/sshd_config
systemctl restart ssh

# Configure Nginx for wildcard subdomains and dynamic port forwarding
log_info "Configuring Nginx for wildcard subdomains and ports..."
tee /etc/nginx/sites-available/tunnel_service <<EOF
server {
    listen 80;
    server_name *.qurtnex.net.ng;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Port \$server_port;
    }
}
EOF

ln -s /etc/nginx/sites-available/tunnel_service /etc/nginx/sites-enabled/
nginx -t && log_info "Nginx configuration test successful."
systemctl restart nginx && log_info "Nginx restarted."

# Path to Cloudflare API token file
CLOUDFLARE_API_TOKEN_PATH="/etc/letsencrypt/cloudflare.ini"

# Check if the Cloudflare API token file exists
if [ ! -f "$CLOUDFLARE_API_TOKEN_PATH" ]; then
    log_info "Cloudflare API token file not found at $CLOUDFLARE_API_TOKEN_PATH"
    log_info "Please create the file with the following content:"
    log_info "dns_cloudflare_api_token = your_cloudflare_api_token"
    exit 1
fi

# Ensure the Cloudflare API token file has the correct permissions
log_info "Ensuring correct permissions for the Cloudflare API token file..."
chmod 600 "$CLOUDFLARE_API_TOKEN_PATH"
chown root:root "$CLOUDFLARE_API_TOKEN_PATH"

# Check if the SSL certificate already exists
CERT_PATH="/etc/letsencrypt/live/qurtnex.net.ng/fullchain.pem"
if [ -f "$CERT_PATH" ]; then
    log_info "SSL certificate already exists, skipping Certbot..."
else
    log_info "Configuring SSL certificates with Certbot using DNS-01 challenge..."
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials "$CLOUDFLARE_API_TOKEN_PATH" \
        --agree-tos --no-eff-email -m admin@qurtnex.net.ng -d "*.qurtnex.net.ng" && log_info "SSL certificates configured successfully."
fi

# Create a general user for tunneling
USERNAME="tunnel"
log_info "Creating user '$USERNAME' with password '$USERNAME'..."
if ! id "$USERNAME" &>/dev/null; then
    adduser --gecos "" "$USERNAME"
    echo "$USERNAME:$USERNAME" | chpasswd
    usermod -aG sudo "$USERNAME"
    log_info "User '$USERNAME' created and configured."
else
    log_info "User '$USERNAME' already exists."
fi

# Ensure PAM is configured for the dynamos service
log_info "Configuring PAM for the dynamos service..."
tee /etc/pam.d/dynamos <<EOF
#%PAM-1.0
auth required pam_unix.so
account required pam_unix.so
session required pam_unix.so
EOF

# Set up logging
log_info "Setting up logging directory and permissions..."
mkdir -p /var/log/tunnel_service
chown www-data:adm /var/log/tunnel_service
chown -R "$USERNAME":"$USERNAME" /var/log/tunnel_service
chmod 750 /var/log/tunnel_service
log_info "Logging directory and permissions set."

log_info "Nginx and SSH services configured successfully."
