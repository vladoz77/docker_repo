#! /bin/bash
set -euo pipefail
set -a        
source .env   
set +a  

# Check if docker container is running
if docker ps --format '{{.Names}}' | grep -q "^${DOCKER_CONTAINER_NAME}$"; then
    echo "Stopping docker container ${DOCKER_CONTAINER_NAME}..."
    docker compose down
else
    echo "Docker container ${DOCKER_CONTAINER_NAME} is not running"
fi

# Remove Traefik configuration files
echo "Removing Traefik configuration files..."
if [ -d ./config ]; then
    rm -rf ./config
    echo "Traefik configuration files removed successfully."
else
    echo "Traefik configuration files do not exist."
fi

# Remove acme.json file
if [ -d ./acme ]; then
    rm -rf ./acme
    echo "acme directory removed successfully."
else
    echo "acme directory does not exist."
fi