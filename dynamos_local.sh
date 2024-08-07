#!/bin/bash

generate_random_subdomain() {
    echo "subdomain-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8).qurtnex.net.ng"
}

SUBDOMAIN=$(generate_random_subdomain)

LOCAL_HOST=$1
LOCAL_PORT=$2
REMOTE_PORT=$3

if [ -z "$LOCAL_HOST" ] || [ -z "$LOCAL_PORT" ] || [ -z "$REMOTE_PORT" ]; then
    echo "Usage: $0 <local_host> <local_port> <remote_port>"
    exit 1
fi

# Generate and copy SSH key if not already present
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
    ssh-copy-id -i ~/.ssh/id_ed25519.pub tunnel@qurtnex.net.ng
fi

# Establish SSH Tunnel
ssh -R $REMOTE_PORT:localhost:$LOCAL_PORT tunnel@qurtnex.net.ng

echo "Access your application at http://$SUBDOMAIN"
