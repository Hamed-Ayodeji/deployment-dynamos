# deployment-dynamos
Building an Alternative Tunneling Service

## Make Wrapper Executable
chmod +x /usr/local/bin/ssh_tunnel_wrapper.sh

## Update sshd_config

Edit the SSH server configuration file (/etc/ssh/sshd_config) to use the wrapper script with ForceCommand:
ForceCommand /usr/local/bin/ssh_tunnel_wrapper.sh
sudo systemctl restart ssh