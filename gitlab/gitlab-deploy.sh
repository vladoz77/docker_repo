#! /bin/bash
set -euo pipefail

set -a        
source .env   
set +a        
echo "Create config dir"
mkdir -p ./gitlab/config ./traefik

echo "Add config files for gitlab and traefik"
envsubst < ./templates/traefik.yml.template > ./traefik/traefik.yml
envsubst < ./templates/gitlab.rb.template > ./gitlab/config/gitlab.rb

echo "Add acme.json"
touch ./traefik/acme.json
chmod 600 ./traefik/acme.json

echo "Run project"
docker compose pull && docker compose up -d
