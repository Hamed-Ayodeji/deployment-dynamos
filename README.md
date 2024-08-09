# deployment-dynamos **`dynamos_remote.sh`**

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Setup and Usage](#setup-and-usage)
  - [1. Setup](#1-setup)
  - [2. Usage](#2-usage)
  - [3. Managing and Debugging](#3-managing-and-debugging)
- [Security](#security)
  - [1. SSH-Based Tunneling](#1-ssh-based-tunneling)
  - [2. Nginx Proxy Management](#2-nginx-proxy-management)
  - [3. Restricted SSH Access](#3-restricted-ssh-access)
  - [4. Controlled Port Access](#4-controlled-port-access)
  - [5. Automated Security Measures](#5-automated-security-measures)
  - [6. Logging and Monitoring](#6-logging-and-monitoring)
- [Future Improvements](#future-improvements)
- [Conclusion](#conclusion)

## Introduction

In today’s digital landscape, secure and efficient remote access to local applications is crucial for developers, IT professionals, and businesses. Traditional methods of exposing local services to the internet, like setting up static IPs or using third-party tunneling services, often introduce complexities and potential security risks.

To address these challenges, **`dynamos_remote.sh`** was developed as a streamlined alternative that mimics the functionality of services like Serveo.net. This Bash script combines SSH reverse tunneling with automated Nginx proxy management, allowing users to securely expose their local applications to the internet with minimal configuration. By automating the creation of unique subdomains, managing SSL certificates, and handling Nginx configurations, `dynamos_remote.sh` offers a simple yet powerful solution for remote access without reliance on third-party services.

## Features

`dynamos_remote.sh` is a straightforward yet powerful tunneling service that mimics Serveo.net, providing dynamic public URLs for securely accessing local applications. Key features include:

1. **SSH Reverse Forwarding**
   - **Dynamic Port Forwarding**: Reverse forward local ports to a public URL using familiar SSH syntax:

     ```bash
     ssh -R 8080:localhost:<local_port> tunnel@thequrtbuck.com.ng
     ```

   - **Automatic URL Generation**: Each session generates a unique subdomain, providing a public URL to access the local application.

2. **Nginx Proxy Management**
   - **Automated Proxy Setup**: Automatically configures Nginx to forward traffic from ports 80 and 443 to your local application.
   - **SSL Support**: Manages SSL certificates via Certbot for secure HTTPS access.

3. **Wildcard Domain Support**
   - **Subdomain Flexibility**: Supports wildcard domains, enabling dynamic subdomains for different applications, managed through Nginx.

4. **Streamlined SSH Access**
   - **Passwordless SSH Authentication**: Automates SSH configuration, allowing easy tunnel creation without manual authentication steps.

## Setup and Usage

`dynamos_remote.sh` is designed for easy setup and use, providing a seamless experience for exposing local applications to the internet.

### 1. Setup

1. **Clone the Repository:**

   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. **Make the Script Executable:**

   ```bash
   chmod +x dynamos_remote.sh
   ```

3. **Run the Script:**

   ```bash
   ./dynamos_remote.sh
   ```

4. **DNS Challenge for SSL:**
   - The script prompts you to manually add a DNS TXT record for SSL verification. Follow the provided instructions to update your DNS settings. Once the DNS changes propagate, the script will continue with the setup.

5. **Automatic Configuration:**
   - The script automatically configures SSH for reverse tunneling, sets up Nginx as a reverse proxy, and manages SSL certificates with minimal intervention.

### 2. Usage

1. **Basic Usage:**

   ```bash
   ssh -R 8080:localhost:3000 tunnel@thequrtbuck.com.ng
   ```

   - This creates a tunnel forwarding traffic from `thequrtbuck.com.ng` to your local application on port 3000.

2. **Accessing the Public URL:**
   - After running the SSH command, you’ll receive a unique public URL like `https://<subdomain>.thequrtbuck.com.ng`.

3. **Handling Multiple Applications:**
   - Run additional SSH commands with different local ports to generate unique subdomains for multiple applications.

4. **Secure Access with SSL:**
   - SSL certificates are automatically handled, ensuring all public URLs are accessible over HTTPS.

### 3. Managing and Debugging

1. **Nginx Configuration:**
   - Nginx configuration files are automatically managed and can be manually edited in `/etc/nginx/sites-available/` if needed.

2. **Logs and Debugging:**
   - Logs are stored in `/home/tunnel/debug.log` for troubleshooting.

## Security

Security is central to `dynamos_remote.sh`, ensuring that your local applications are exposed to the internet safely.

### 1. SSH-Based Tunneling

- **Passwordless SSH Authentication**: Configures a dedicated `tunnel` user with passwordless SSH access, restricted to tunneling only.
- **ForceCommand for Tunneling**: Limits the `tunnel` user to executing the `auto_setup.sh` script, preventing arbitrary commands.

### 2. Nginx Proxy Management

- **SSL/TLS Encryption**: Automatically configures Nginx to secure all public URLs with SSL/TLS encryption, managed by Certbot.
- **Isolated Subdomains**: Each session generates a unique subdomain, isolating applications from each other.

### 3. Restricted SSH Access

- **User Privilege Limitation**: The `tunnel` user has minimal privileges and is restricted from typical SSH activities.
- **PAM Authentication Management**: Integrates with PAM to enforce secure authentication policies for the `tunnel` user.

### 4. Controlled Port Access

- **Port Management**: Nginx is configured to expose only essential ports (80 and 443), reducing the risk of unauthorized access.
- **GatewayPorts Configuration**: SSH is configured to manage `GatewayPorts` securely.

### 5. Automated Security Measures

- **Package Updates**: Automatically updates SSH, Nginx, and Certbot during setup to ensure security patches are applied.
- **Automated SSL Management**: Manages SSL certificates, including automatic renewals, to maintain secure connections.

### 6. Logging and Monitoring

- **Activity Logging**: Logs all SSH and Nginx activities related to the tunneling service for auditing and security monitoring.

## Future Improvements

`dynamos_remote.sh` can be enhanced with:

1. **Support Multiple Tunnels**: Allow multiple tunnels within a single session.
2. **Advanced Authentication**: Add SSH keypair support and Two-Factor Authentication (2FA).
3. **Dynamic DNS Management**: Automate DNS record management with DNS provider API integration.
4. **Custom Nginx Configurations**: Enable custom Nginx settings and automatic certificate renewal notifications.
5. **Enhanced Logging and Monitoring**: Introduce real-time monitoring and advanced log analysis tools.
6. **Cross-Platform Compatibility**: Expand support to Windows and Docker environments.
7. **User-Friendly Interface**: Develop a web-based control panel and interactive CLI options.

## Conclusion

`dynamos_remote.sh` is a secure and straightforward solution for exposing local applications to the internet using SSH reverse tunneling and Nginx proxy management. With features like passwordless SSH, automated SSL, and isolated subdomains, it ensures easy and secure access. Future enhancements will further improve its functionality and usability, making it an even more valuable tool for developers and IT professionals.
