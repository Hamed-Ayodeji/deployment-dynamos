#!/bin/bash

# Generate a unique subdomain
SUBDOMAIN=$(uuidgen | cut -d'-' -f1)

# Create Nginx configuration for the new subdomain
cat <<EOF > /etc/nginx/sites-available/${SUBDOMAIN}.conf
server {
    listen 80;
    server_name ${SUBDOMAIN}.jotvault.tech;

    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the new configuration
ln -s /etc/nginx/sites-available/${SUBDOMAIN}.conf /etc/nginx/sites-enabled/${SUBDOMAIN}.conf

# Reload Nginx to apply changes
systemctl reload nginx

# Output the URL
echo "http://${SUBDOMAIN}.jotvault.tech"