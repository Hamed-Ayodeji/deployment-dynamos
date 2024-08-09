## Alternative Tunneling Service

This documentation provides a comprehensive overview of the project, its features, installation instructions, and usage guidelines.

**Project Title:** Alternative Tunneling Service

**Project Description:**

This project aims to develop an alternative tunneling service similar to ngrok and serveo.net. The service utilizes SSH reverse forwarding to provide dynamic public URLs for accessing local applications. It allows users to reverse forward ports and access their applications via a unique URL, simplifying remote access to development environments and applications.

**Key Features:**

- **SSH Reverse Forwarding:** The service leverages SSH reverse forwarding to dynamically route traffic from a remote server to a local machine.
- **Proxy Management:** Nginx is employed to manage HTTP/HTTPS proxy settings, ensuring proper handling of traffic on port 80.
- **Wildcard Domains:** Support for wildcard domains is integrated, enabling flexible subdomain management for tunneling.

**Technical Areas:**

- **SSH Configuration:**
    - **Reverse Forwarding:** The service enables reverse port forwarding, allowing access to applications running locally on your machine through a public URL.
    - **PAM Authentication:** Pluggable Authentication Modules (PAM) are configured to manage passwordless authentication for the tunnel user.

- **Proxy Management:**
    - **Nginx Configuration:** The service sets up Nginx as a reverse proxy, handling requests and forwarding them to the appropriate local ports based on the subdomain used.
    - **SSL/TLS Certificates:** The service utilizes Let's Encrypt to obtain SSL/TLS certificates for securing communication over HTTPS.

- **Port Forwarding:**
    - **Dynamic Port Forwarding:** Users can dynamically specify the local port they wish to forward, which will be associated with a unique subdomain.

- **Wildcard Domains:**
    - **Domain Management:** The service supports wildcard domains, allowing users to access different services via distinct subdomains.

**Installation:**

**Prerequisites:**

- A server with a public domain (e.g., `qurtnex.net.ng`).
- SSH access to the server.
- Root privileges on the server.
- DNS management access for the domain.

**Setup Instructions:**

1. **Clone the Repository:**

   ```bash
   git clone <repository_url>
   cd <repository_directory>
   ```

2. **Run the Setup Script:**

   The provided setup script will configure the server, including SSH, Nginx, and SSL certificates.

   ```bash
   sudo ./dynamos_remote.sh
   ```

   Follow the on-screen instructions to complete the setup, including adding a DNS TXT record for SSL verification.

3. **Access the Tunneling Service:**

   Once the setup is complete, you can use the following command to start tunneling:

   ```bash
   ssh -R <remote_port>:localhost:<local_port> tunnel@qurtnex.net.ng
   ```

   The service will provide you with a unique URL to access your application.

**Usage:**

- **Starting a Tunnel:**
  Use the SSH command provided during setup to reverse forward a local port.

- **Accessing Your Application:**
  Visit the unique URL provided by the service to access your application publicly.

**Example Usage:**

```bash
ssh -R 80:localhost:3000 tunnel@qurtnex.net.ng
```

This command forwards traffic from port 80 on the remote server to port 3000 on your local machine. The service will provide you with a public URL, such as `https://abcde.qurtnex.net.ng`, where your application can be accessed.

**Contribution:**

We welcome contributions! Please follow these steps:

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Commit your changes (`git commit -m 'Add feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Open a pull request.




