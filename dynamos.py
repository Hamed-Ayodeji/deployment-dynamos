import subprocess
import sys
import random
import string
import logging
import argparse
import os

# Set up logging
logging.basicConfig(filename='/var/log/tunnel_service/dynamos.log', level=logging.INFO, format='%(asctime)s %(message)s')

# Function to generate a random subdomain
def generate_subdomain(custom_subdomain=None):
    if custom_subdomain:
        return f"{custom_subdomain}.qurtnex.net.ng"
    return "subdomain-" + ''.join(random.choices(string.ascii_lowercase + string.digits, k=8)) + ".qurtnex.net.ng"

# Function to set up SSH reverse forwarding
def setup_reverse_forwarding(local_address, subdomain, debug):
    local_host, local_port = local_address.split(":")

    ssh_command = [
        "ssh",
        "-o", "StrictHostKeyChecking=accept-new",
        "-R", f"80:{local_host}:{local_port}",
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
User=tunnel
ExecStart={' '.join(ssh_command)}
Restart=always

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
    parser = argparse.ArgumentParser(description="Set up a reverse SSH tunnel and create a systemd service.")
    parser.add_argument("local_address", help="Local address and port in the format <address>:<port>")
    parser.add_argument("-s", "--subdomain", help="Custom subdomain to use (default: randomly generated)")
    parser.add_argument("-d", "--debug", action="store_true", help="Enable debug output")

    args = parser.parse_args()

    subdomain = generate_subdomain(args.subdomain)
    setup_reverse_forwarding(args.local_address, subdomain, args.debug)
