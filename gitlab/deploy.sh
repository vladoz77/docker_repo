#! /bin/bash
set -euo pipefail

set -a        
source .env   
set +a        

envsubst < ./traefik/traefik.yml.template > ./traefik/traefik.yml
envsubst < ./gitlab/config/gitlab.rb.template > ./gitlab/config/gitlab.rb

touch ./traefik/acme.json
chmod 600 ./traefik/acme.json

docker compose up -d
