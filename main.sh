#!/bin/bash

# Update package lists
sudo apt update

# Install necessary packages
sudo apt install -y openssh-server nginx

# Enable and start SSH service
sudo systemctl enable ssh
sudo systemctl start ssh

# Configure SSH to allow gateway ports for reverse forwarding
sudo sed -i '/^#GatewayPorts no/c\GatewayPorts yes' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Generate SSH key pair without a passphrase
ssh-keygen -t rsa -b 2048 -f ~/.ssh/tunnel_key -N ""

# Copy the public key to the remote server
echo "Copying SSH public key to the remote server."
ssh-copy-id -i ~/.ssh/tunnel_key.pub root@161.35.9.238

# Create an Nginx configuration file for the tunneling service
sudo tee /etc/nginx/sites-available/tunnel_service <<EOF
server {
    listen 80;
    server_name {{ SERVER_NAME_PATTERN }};

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Define the variable
SERVER_NAME_PATTERN='~^subdomain-[a-z0-9]{8}\.dynamos\.tunnelprime\.com$'

# Replace placeholder in the template
sudo sed -i "s/{{ SERVER_NAME_PATTERN }}/$SERVER_NAME_PATTERN/" /etc/nginx/sites-available/tunnel_service

# Enable the Nginx configuration
if [ -L /etc/nginx/sites-enabled/tunnel_service ]; then
    sudo rm /etc/nginx/sites-enabled/tunnel_service
fi
sudo ln -s /etc/nginx/sites-available/tunnel_service /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Restart Nginx if configuration is valid
if [ $? -eq 0 ]; then
    sudo systemctl restart nginx
else
    echo "Nginx configuration test failed."
    exit 1
fi

# Create the tunneling service script
cat <<'EOF' > ~/tunnel_service.sh
#!/bin/bash

# Function to generate a random subdomain
generate_subdomain() {
  echo "subdomain-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8).dynamos.tunnelprime.com"
}

# Function to set up SSH reverse forwarding
setup_reverse_forwarding() {
  local local_port=$1
  local subdomain=$(generate_subdomain)

  ssh -i ~/.ssh/tunnel_key -R 80:localhost:${local_port} root@161.35.9.238 -N &
  local ssh_pid=$!

  echo "Tunnel established. Access your application at http://${subdomain}"
  echo "SSH PID: ${ssh_pid}"

  # Save the PID to terminate later if needed
  echo ${ssh_pid} > "/tmp/tunnel_${subdomain}.pid"
}
EOF

# Make the tunneling service script executable
chmod +x ~/tunnel_service.sh

echo "Setup is complete."
