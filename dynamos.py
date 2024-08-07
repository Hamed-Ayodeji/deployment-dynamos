#!/usr/bin/env python3

import subprocess
import sys
import random
import string
import logging
import argparse
import os

# Set up logging directory
LOG_DIR = '/var/log/tunnel_service'
if not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR, exist_ok=True)
    os.chmod(LOG_DIR, 0o750)
    os.chown(LOG_DIR, -1, -1)

# Set up logging
logging.basicConfig(filename=os.path.join(LOG_DIR, 'dynamos.log'), level=logging.INFO, format='%(asctime)s %(message)s')

# Function to generate a random subdomain
def generate_subdomain(custom_subdomain=None):
    if custom_subdomain:
        return f"{custom_subdomain}.qurtnex.net.ng"
    return "subdomain-" + ''.join(random.choices(string.ascii_lowercase + string.digits, k=8)) + ".qurtnex.net.ng"

# Function to set up SSH reverse forwarding
def setup_reverse_forwarding(local_address, subdomain, debug):
    if ":" in local_address:
        local_host, local_port = local_address.split(":")
    else:
        local_host = local_address
        local_port = "80"

    remote_port = "8080"  # Use a higher port to avoid permission issues

    ssh_command = [
        "ssh",
        "-i", "/root/.ssh/id_ed25519",  # Specify the path to your private key
        "-o", "StrictHostKeyChecking=accept-new",
        "-R", f"{remote_port}:localhost:{local_port}",
        "tunnel@qurtnex.net.ng",
        "-N"
    ]

    # Create systemd service
    service_name = f"tunnel_{subdomain}.service"
    service_content = f"""
[Unit]
Description=Tunnel Service for {subdomain}
After=network.target

[Service]
User=root
ExecStart={' '.join(ssh_command)}
Restart=always
StandardOutput=journal+console
StandardError=journal+console
SyslogIdentifier=tunnel_{subdomain}

[Install]
WantedBy=multi-user.target
"""

    service_file = f"/etc/systemd/system/{service_name}"
    with open(service_file, "w") as file:
        file.write(service_content)

    # Enable and start the systemd service
    subprocess.run(["systemctl", "daemon-reload"])
    subprocess.run(["systemctl", "enable", service_name])
    subprocess.run(["systemctl", "start", service_name])

    logging.info(f"Tunnel established for {local_address}. Access your application at http://{subdomain}")
    print(f"Tunnel established. Access your application at http://{subdomain}")
    print(f"Systemd service name: {service_name}")

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
