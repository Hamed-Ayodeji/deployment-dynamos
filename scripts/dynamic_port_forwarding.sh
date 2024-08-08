#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <unique_port> <remote_server>"
    exit 1
fi

UNIQUE_PORT=$1
REMOTE_SERVER=$2

# Path to the SSH private key for the predefined user (e.g., ubuntu)
SSH_KEY="$HOME/.ssh/id_rsa"

# Setup reverse port forwarding
ssh -n -N -i $SSH_KEY -R $UNIQUE_PORT:localhost:8080 ubuntu@$REMOTE_SERVER &

# Print the unique URL for the user
echo "Your unique URL is: http://$UNIQUE_PORT.bestbuy.crabdance.com"

