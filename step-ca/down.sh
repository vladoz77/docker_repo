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

# Check if docker container is running
if docker ps --format '{{.Names}}' | grep -q "^${DOCKER_CONTAINER_NAME}$"; then
    echo "Stopping docker container ${DOCKER_CONTAINER_NAME}..."
    docker compose down
else
    echo "Docker container ${DOCKER_CONTAINER_NAME} is not running"
fi

# Check if docker volume exists
if docker volume inspect "${DOCKER_VOLUME_NAME}" >/dev/null 2>&1; then
    echo "Removing docker volume ${DOCKER_VOLUME_NAME}..."
    docker volume rm "${DOCKER_VOLUME_NAME}" >/dev/null 2>&1
else
    echo "Docker volume ${DOCKER_VOLUME_NAME} does not exist"
fi

# Remove the root CA certificate if it exists
if [ -f "${ROOT_CA_CERT_PATH}" ]; then
    echo "Removing root CA certificate at ${ROOT_CA_CERT_PATH}..."
    sudo rm -f "${ROOT_CA_CERT_PATH}" >/dev/null 2>&1
    echo "Root CA certificate removed"
else
    echo "Root CA certificate at ${ROOT_CA_CERT_PATH} does not exist"
fi