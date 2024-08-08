#!/bin/bash

# Ensure the script is run as root
if [[ "$(id -u)" -ne 0 ]]; then
    sudo -E "$0" "$@"
    exit
fi

# Variables
TUNNEL_USER="tunnel"

# Function to print messages
print_message() {
  echo -e "\n>>> $1\n"
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
if ! id -u $TUNNEL_USER > /dev/null 2>&1; then
    adduser --disabled-password --gecos "" $TUNNEL_USER
    usermod -aG sudo $TUNNEL_USER
    passwd -d $TUNNEL_USER
else
    print_message "User $TUNNEL_USER already exists."
fi

# Update and install required packages
print_message "Updating package list and installing required packages..."
apt update && apt install -y openssh-server

# Configure SSH for passwordless access for the tunnel user
print_message "Configuring SSH..."
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords.*/PermitEmptyPasswords yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#UsePAM.*/UsePAM no/' /etc/ssh/sshd_config

# Add configuration for tunnel user
cat >> /etc/ssh/sshd_config <<EOL

# Allow passwordless login for tunnel user
Match User $TUNNEL_USER
    PermitEmptyPasswords yes
    PasswordAuthentication no
    PubkeyAuthentication no
    ChallengeResponseAuthentication no
    AuthenticationMethods none
EOL

# Restart SSH service to apply changes
print_message "Restarting SSH service..."
systemctl restart ssh

print_message "Setup completed successfully. You can now connect to the server without authentication using the tunnel user."

