#! /bin/bash
set -euo pipefail

set -a        
source .env   
set +a        

mkdir -p ./gitlab/config ./traefik
envsubst < ./templates/traefik.yml.template > ./traefik/traefik.yml
envsubst < ./templates/gitlab.rb.template > ./gitlab/config/gitlab.rb

touch ./traefik/acme.json
chmod 600 ./traefik/acme.json

docker compose pull && docker compose up -d
