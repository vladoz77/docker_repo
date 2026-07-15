#! /bin/bash
set -euo pipefail

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Please create the .env file with the required configuration"
    exit 1
else
    echo ".env file found"
fi

set -a        
source .env   
set +a


# Check if step-ca is running
if ! curl -sk https://localhost:9000/health | jq -e '.status == "ok"' > /dev/null 2>&1  ; then
    echo "step-ca is not running. Please start step-ca before running this script."
    exit 1
else
    echo "step-ca is running"
fi

# Check if root CA certificate exists
if [ ! -f "${ROOT_CA_DIR}" ]; then
    echo "Root CA certificate not found at ${TRAEFIK_CACERTIFICATE}. Please ensure the certificate exists and the path is correct."
    exit 1
else
    echo "Root CA certificate found at ${TRAEFIK_CACERTIFICATE}"
fi

# Generate configuration files for Traefik
echo "Generating Traefik configuration files..."
mkdir -p ./config
envsubst < ./templates/traefik.yml.tmpl > ./config/traefik.yml
echo "Traefik configuration files generated successfully."

# Create acme.json file if it doesn't exist
echo "Create acme.json file if it doesn't exist..."
if [ ! -f ./acme/acme.json ]; then
    echo "acme.json file does not exist. Creating it now..."
    mkdir -p ./acme
    touch ./acme/acme.json
    chmod 600 ./acme/acme.json
    echo "acme.json file created and permissions set to 600."
else
    echo "acme.json file already exists."
fi

# Check if the Docker network exists, and create it if it doesn't
echo "Checking if Docker network ${DOCKER_NETWORK} exists..."
if ! docker network inspect "${DOCKER_NETWORK}" >/dev/null 2>&1; then
    echo "Docker network ${DOCKER_NETWORK} does not exist. Creating it now..."
    
    docker network create \
    --subnet "${DOCKER_SUBNET}" \
    --gateway "${DOCKER_GATEWAY}" \
        "${DOCKER_NETWORK}"

    echo "Docker network ${DOCKER_NETWORK} created successfully."
else
    echo "Docker network ${DOCKER_NETWORK} already exists."
fi

# Start Traefik using Docker Compose
# Check if docker container running
if docker ps --format '{{.Names}}' | grep -q "^${DOCKER_CONTAINER_NAME}$"; then
    echo "Docker container ${DOCKER_CONTAINER_NAME} is already running"
    exit 1
else
    echo "Starting docker container ${DOCKER_CONTAINER_NAME}..."
    docker compose up -d
fi
