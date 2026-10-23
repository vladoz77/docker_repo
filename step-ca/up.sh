#! /bin/bash
set -euo pipefail
set -a        
source .env
set +a

# Check if run from root user
if [ "$EUID" -ne 0 ]; then  
    echo "Please run as root"
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Please create the .env file with the required configuration"
    exit 1
else
    echo ".env file found"
fi

# Check if docker network exists
if ! docker network inspect "${DOCKER_NETWORK}" >/dev/null 2>&1; then
    echo "Please create the docker network ${DOCKER_NETWORK} for connect step-ca and traefik"
    exit 1
fi

# Check if docker container running
if docker ps --format '{{.Names}}' | grep -q "^${DOCKER_CONTAINER_NAME}$"; then
    echo "Docker container ${DOCKER_CONTAINER_NAME} is already running"
    exit 1
else
    echo "Starting docker container ${DOCKER_CONTAINER_NAME}..."
    docker compose up -d
fi

# Wait for the container to be ready
echo "Waiting for the container ${DOCKER_CONTAINER_NAME} to be ready..."
until curl  http://${DOCKER_CONTAINER_IP}:9000/health >/dev/null 2>&1; do
    sleep 5
done
echo "Container ${DOCKER_CONTAINER_NAME} is ready."

# Copy the root CA certificate to /tmp/root_ca.crt
docker exec "${DOCKER_CONTAINER_NAME}" cat /home/step/certs/root_ca.crt > ${ROOT_CA_CERT_PATH}
echo "Root CA certificate copied to ${ROOT_CA_CERT_PATH}"

# Add the root CA certificate to the system's trusted certificates
if [ -f "${ROOT_CA_CERT_PATH}" ]; then
    echo "Adding root CA certificate to the system's trusted certificates..."
    sudo install -D -m 0644 /tmp/root_ca.crt /etc/pki/ca-trust/source/anchors/root_ca.crt
    sudo update-ca-trust
    echo "Root CA certificate added to the system's trusted certificates"
else
    echo "Root CA certificate not found at ${ROOT_CA_CERT_PATH}"
fi

