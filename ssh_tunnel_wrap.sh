#!/bin/bash

# Check if the SSH connection has port forwarding (tunneling)
if [ "$SSH_TTY" != "" ] && [ "$SSH_CONNECTION" != "" ]; then
    if echo "$SSH_CONNECTION" | grep -q '127.0.0.1'; then
        /usr/local/bin/auto_subdomain.sh
    else
        # No port forwarding; just run the shell
        exec /bin/bash
    fi
else
    # Not an SSH connection or not a tunneling connection
    exec /bin/bash
fi
