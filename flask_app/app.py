from flask import Flask, request, jsonify, render_template
import subprocess
import random
import logging

app = Flask(__name__)

REMOTE_SERVER = "13.58.222.123"  # Public SSH server IP

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s %(levelname)s %(message)s', datefmt='%Y-%m-%d %H:%M:%S')

def generate_unique_port():
    return random.randint(1024, 65535)

@app.route('/')
def home():
    return render_template('hng_internship.html')

@app.route('/request_access', methods=['POST'])
def request_access():
    user_id = request.form['user_id']
    logging.info(f'Received request from user: {user_id}')
    
    # Generate a unique port number within a range to avoid conflicts
    unique_port = generate_unique_port()
    logging.info(f'Generated unique port: {unique_port}')
    
    # Execute the reverse port forwarding script
    logging.debug(f"Setting up reverse port forwarding for port {unique_port}")
    subprocess.Popen(['/home/ubuntu/scripts/dynamic_port_forwarding.sh', str(unique_port), REMOTE_SERVER])
    
    unique_url = f'http://{unique_port}.bestbuy.crabdance.com'
    logging.info(f'Returning URL to user: {unique_url}')
    return jsonify({'user_id': user_id, 'url': unique_url})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)

