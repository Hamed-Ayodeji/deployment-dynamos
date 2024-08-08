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

# Create the auto_setup.py script
print_message "Creating the auto setup script..."
AUTO_SETUP_SCRIPT="/usr/local/bin/auto_setup.py"
cat > $AUTO_SETUP_SCRIPT <<'EOF'
#!/usr/bin/env python3

import os
import subprocess
import uuid

# Function to print messages
def print_message(message):
    print(f"\n>>> {message}\n")

def main():
    # Read the SSH_ORIGINAL_COMMAND environment variable
    original_command = os.environ.get("SSH_ORIGINAL_COMMAND", "")
    
    if not original_command:
        print("This script should be run automatically on SSH login.")
        return

    # Extract remote port, host, and local port from the SSH command
    try:
        remote_port = original_command.split('-R ')[1].split(':')[0]
        host = original_command.split('-R ')[1].split(':')[1]
        local_port = original_command.split('-R ')[1].split(':')[2].split(' ')[0]
    except IndexError:
        print("Failed to parse remote port, host, or local port from the SSH command.")
        return

    # Generate a unique subdomain
    subdomain = uuid.uuid4().hex[:8]

    # Configure Nginx for the unique subdomain
    nginx_conf = f"""
server {{
    listen 80;
    server_name {subdomain}.qurtnex.net.ng;
    location / {{
        proxy_pass http://localhost:{remote_port};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }}
}}

server {{
    listen 443 ssl;
    server_name {subdomain}.qurtnex.net.ng;

    ssl_certificate /etc/letsencrypt/live/qurtnex.net.ng/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/qurtnex.net.ng/privkey.pem;

    location / {{
        proxy_pass http://localhost:{remote_port};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }}
}}
"""

    nginx_conf_path = f"/etc/nginx/sites-available/{subdomain}"
    
    with open(nginx_conf_path, 'w') as f:
        f.write(nginx_conf)

    # Enable the Nginx configuration
    os.symlink(nginx_conf_path, f"/etc/nginx/sites-enabled/{subdomain}")
    subprocess.run(["nginx", "-t"])
    subprocess.run(["systemctl", "reload", "nginx"])

    # Display the URLs in a tabular format
    local_url = f"http://{host}:{local_port}"
    public_url = f"https://{subdomain}.qurtnex.net.ng"
    
    print_message("Local URL            Public URL")
    print_message("-------------------  ------------------------")
    print_message(f"{local_url}  {public_url}")
    print_message("Setup completed successfully.")
    print_message("Press [CTRL+C] to exit")
    
    # Keep the session open for debugging
    subprocess.run(["tail", "-f", "/dev/null"])

if __name__ == "__main__":
    main()
EOF

chmod +x /usr/local/bin/auto_setup.py

# Create a sudoers file for the tunnel user
print_message "Creating sudoers file for tunnel user..."
SUDOERS_FILE="/etc/sudoers.d/tunnel"
cat > $SUDOERS_FILE <<EOF
tunnel ALL=(ALL) NOPASSWD: /usr/local/bin/auto_setup.py
EOF

# Add or modify an entry in the authorized_keys file to include the command
AUTHORIZED_KEYS_FILE="/home/$TUNNEL_USER/.ssh/authorized_keys"
SSH_PUBLIC_KEY="<your-ssh-public-key>"  # Replace this with your actual SSH public key

if ! grep -q "command=\"/usr/local/bin/auto_setup.py\"" "$AUTHORIZED_KEYS_FILE"; then
  echo "command=\"/usr/local/bin/auto_setup.py\",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty $SSH_PUBLIC_KEY" >> "$AUTHORIZED_KEYS_FILE"
fi

print_message "Setup completed successfully. To use the setup, run the following SSH command from your local machine:"
echo "ssh -R <remote_port>:localhost:<local_port> tunnel@$DOMAIN"
