#! /bin/bash
set -e
source .env
set -a

envsubst < ./traefik/traefik.yml.template > ./traefik/traefik.yml
envsubst < ./gitlab/gitlab.rb.template > ./gitlab/gitlab.rb

docker-compose up -d