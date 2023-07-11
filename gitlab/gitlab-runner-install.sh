#!/bin/sh


registration_token=GR1348941xDs4ESxmPmhKF5x_huSp
url=http://gitlab.home.local/

docker exec -it gitlab-runner \
  gitlab-runner register \
    --non-interactive \
    --registration-token ${registration_token} \
    --locked=false \
    --description docker-stable \
    --url ${url} \
    --executor docker \
    --docker-image docker:stable \
    --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
    --docker-network-mode gitlab-network
    