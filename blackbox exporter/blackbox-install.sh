#!/bin/bash

# Script to install Docker and run blackbox-exporter with restricted access
set -e  

# config
ALLOWED_IP="172.16.10.1"
BASE_DIR="/opt/blackbox-exporter"
CERTS_DIR="$BASE_DIR/certs"
IMAGE="prom/blackbox-exporter"
CONTAINER_NAME="blackbox-exporter"
VERSION="latest"
PORT="9115"



# check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or use sudo"
  exit 1
fi

# Install docker if not install
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
else
    echo "Docker is already installed."
fi

# Start docker service
echo "Starting Docker service..."
systemctl enable --now docker

# Creation of directories for blackbox-exporter configuration
echo "Creating directory ${BASE_DIR} and ${CERTS_DIR} for blackbox-exporter configuration..."
mkdir -p $BASE_DIR $CERTS_DIR

# Generation of self-signed SSL certificates
echo "Generating self-signed SSL certificates..."
if [ -f "$CERTS_DIR/blackbox.crt" ] || [ -f "$CERTS_DIR/blackbox.key" ]; then
    echo "SSL certificates already exist. Skipping generation."
else
    echo "SSL certificates do not exist. Generating new ones."
    openssl req -newkey rsa:4096 \
      -x509 \
      -sha256 \
      -days 3650 \
      -nodes \
      -out blackbox.crt \
      -keyout blackbox.key \
      -subj "/C=RU/L=Ryazan/O=Fabrika/OU=IT/CN=blackbox.home.local"
    # Move generated certificates to the certs directory
    mv blackbox.crt blackbox.key $CERTS_DIR/
fi

  # Creation of blackbox-exporter configuration file
echo "Creating blackbox-exporter configuration file..."
cat > $BASE_DIR/blackbox.yml << 'EOF'
modules:
  https_endpoint:
    prober: http
    timeout: 15s
    http:
      method: GET
      valid_http_versions:
      - HTTP/1.1
      - HTTP/2.0
      fail_if_not_ssl: true
      no_follow_redirects: false
      ip_protocol_fallback: false
      preferred_ip_protocol: ip4
EOF

# Create blackbox web configuration with TLS
cat > $BASE_DIR/web-config.yml << 'EOF'
tls_server_config:
  cert_file: /certs/blackbox.crt
  key_file: /certs/blackbox.key

basic_auth_users:
  blackbox: $2y$10$1KWGGVB0jhe878t6tUvtYeB8/iudISI9tKHdsfSRMMxFKOIwg9XvC
EOF


# Check if blackbox-exporter container is already running delete if exists
echo "Checking if $CONTAINER_NAME container is running..."
EXISTING=$(docker ps -a -q -f name="^${CONTAINER_NAME}$")
if [ "$EXISTING" ]; then
    echo "$CONTAINER_NAME container is already running, removing it..."
    docker rm -f "$CONTAINER_NAME"
fi

# Run blackbox-exporter container
echo "Running $CONTAINER_NAME container..."
docker run -d --name $CONTAINER_NAME \
  -p $PORT:$PORT \
  -v $BASE_DIR/blackbox.yml:/etc/blackbox_exporter/blackbox.yml \
  -v $BASE_DIR/web-config.yml:/etc/blackbox_exporter/web-config.yml \
  -v $CERTS_DIR:/certs \
  $IMAGE:$VERSION \
  --config.file=/etc/blackbox_exporter/blackbox.yml \
  --web.config.file=/etc/blackbox_exporter/web-config.yml
echo "blackbox-exporter is running."

# Configure iptables to restrict access
echo "Configuring iptables to allow only $ALLOWED_IP..."

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i docker0 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp -s $ALLOWED_IP --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -s $ALLOWED_IP --dport 9115 -j ACCEPT
iptables -A FORWARD -o docker0 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i docker0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "iptables configured. Access restricted to $ALLOWED_IP."
echo "Setup completed successfully."
