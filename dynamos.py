#!/usr/bin/env python3

import subprocess
import sys
import random
import string
import logging
import argparse
import os
from tabulate import tabulate
import time

# Set up logging directory if it does not exist
LOG_DIR = '/var/log/tunnel_service'
if not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR, exist_ok=True)
    os.chmod(LOG_DIR, 0o750)

# Set up logging
logging.basicConfig(filename=os.path.join(LOG_DIR, 'dynamos.log'), level=logging.INFO, format='%(asctime)s %(message)s')

# Function to generate a random subdomain or use a custom one if provided
def generate_subdomain(custom_subdomain=None):
    if custom_subdomain:
        return f"{custom_subdomain}.qurtnex.net.ng"
    return "subdomain-" + ''.join(random.choices(string.ascii_lowercase + string.digits, k=8)) + ".qurtnex.net.ng"

# Function to generate SSH key pair if not exists
def generate_ssh_key():
    key_file = os.path.expanduser("~/.ssh/id_ed25519")
    if not os.path.exists(key_file):
        subprocess.run(["ssh-keygen", "-t", "ed25519", "-f", key_file, "-q", "-N", ""])
    return key_file

# Function to remove old host key if it exists
def remove_old_host_key(remote_host):
    subprocess.run(["ssh-keygen", "-R", remote_host])

# Function to check if SSH key is already on remote server
def is_key_copied(remote_user, remote_host):
    result = subprocess.run(
        ["ssh", "-o", "PasswordAuthentication=no", f"{remote_user}@{remote_host}", "exit"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    return result.returncode == 0

# Function to copy the SSH public key to the remote server with retries
def copy_ssh_key(remote_user, remote_host, retries=5, delay=5):
    key_file = os.path.expanduser("~/.ssh/id_ed25519.pub")
    for attempt in range(retries):
        if not is_key_copied(remote_user, remote_host):
            result = subprocess.run(["ssh-copy-id", "-i", key_file, f"{remote_user}@{remote_host}"])
            if result.returncode == 0:
                logging.info("SSH key copied successfully.")
                return True
            else:
                logging.warning(f"Attempt {attempt + 1} to copy SSH key failed. Retrying in {delay} seconds...")
                remove_old_host_key(remote_host)
                time.sleep(delay)
        else:
            logging.info("SSH key already exists on the remote server.")
            return True
    logging.error("Failed to copy SSH key after multiple attempts.")
    return False

# Function to set up SSH reverse forwarding
def setup_reverse_forwarding(local_address, subdomain, debug):
    # Split the local address into host and port, default to port 80 if not provided
    if ":" in local_address:
        local_host, local_port = local_address.split(":")
    else:
        local_host = local_address
        local_port = "80"

    remote_port = "8080"  # Use a higher port to avoid permission issues

    # Generate SSH key pair if not exists
    ssh_key = generate_ssh_key()
    
    # Copy SSH public key to the remote server with retries
    if not copy_ssh_key("tunnel", "qurtnex.net.ng"):
        logging.error("Failed to set up SSH key for remote access. Exiting...")
        sys.exit(1)

    # SSH command to establish reverse tunnel
    ssh_command = [
        "ssh",
        "-o", "StrictHostKeyChecking=accept-new",
        "-i", ssh_key,
        "-R", f"{remote_port}:localhost:{local_port}",
        "tunnel@qurtnex.net.ng",
        "-N"
    ]

    # Create or update the systemd service for the tunnel
    service_name = "tunnel_service.service"
    service_content = f"""
[Unit]
Description=Tunnel Service
After=network.target

[Service]
User=root
ExecStart={' '.join(ssh_command)}
Restart=always
StandardOutput=journal+console
StandardError=journal+console
SyslogIdentifier=tunnel_service

[Install]
WantedBy=multi-user.target
"""

    service_file = f"/etc/systemd/system/{service_name}"
    with open(service_file, "w") as file:
        file.write(service_content)

    # Enable and start the systemd service
    subprocess.run(["systemctl", "daemon-reload"])
    subprocess.run(["systemctl", "enable", service_name])
    subprocess.run(["systemctl", "restart", service_name])

    logging.info(f"Tunnel established for {local_address}. Access your application at http://{subdomain}")
    # Print the details in a tabular format
    table = [
        ["Local Address", local_address],
        ["Subdomain", subdomain],
        ["Systemd Service", service_name]
    ]
    print(tabulate(table, headers=["Field", "Value"], tablefmt="grid"))

    if debug:
        print(f"SSH command: {' '.join(ssh_command)}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Set up a reverse SSH tunnel and create a systemd service.",
        epilog="Example usage:\n  dynamos 127.0.0.1:3000\n  dynamos 127.0.0.1 -s customsubdomain\n  dynamos 127.0.0.1 -d",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("local_address", help="Local address and port in the format <address>:<port>. If the port is not provided, it defaults to 80.")
    parser.add_argument("-s", "--subdomain", help="Custom subdomain to use (default: randomly generated)")
    parser.add_argument("-d", "--debug", action="store_true", help="Enable debug output")

    args = parser.parse_args()

    subdomain = generate_subdomain(args.subdomain)
    setup_reverse_forwarding(args.local_address, subdomain, args.debug)
