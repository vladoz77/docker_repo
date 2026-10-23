log:
  level: DEBUG

ping: {}

api:
  dashboard: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"
  metrics:
    address: ":8082"

providers:
  docker:
    exposedByDefault: false
    network: proxy

certificatesResolvers:
  homelab:
    acme:
      caServer: https://${STEPCA_HOST}:9000/acme/acme/directory
      caCertificates:
        - /etc/ssl/homelab/root_ca.crt
      storage: /acme/acme.json
      httpChallenge:
        entryPoint: web

metrics:
  prometheus:
    entryPoint: metrics