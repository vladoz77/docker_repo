#! /bin/bash
set -euo pipefail

set -a        
source .env   
set +a        

envsubst < ./traefik/traefik.yml.template > ./traefik/traefik.yml
envsubst < ./gitlab/config/gitlab.rb.template > ./gitlab/config/gitlab.rb

docker compose up -d