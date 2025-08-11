## Docker compose

Create a file docker-compose.yaml and add the following content:

```yaml
services:
  lampac:
    image: immisterio/lampac
    container_name: lampac
    restart: always
    ports:
      - 9118:9118
    volumes:
      - ./init.conf:/home/init.conf
      - ./manifest.json:/home/module/manifest.json
    environment:  
      - TZ=Europe/Moscow  
    networks:  
      - lampac-network 
  nginx:
    image: nginx:latest
    container_name: nginx
    ports:
      - 80:80
      - 443:443
    restart: always
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/lampac.conf:ro
      - ./certbot/conf/:/etc/letsencrypt/:ro
      - ./certbot/www/:/var/www/certbot/:rw
    networks:
      - lampac-network
  certbot:
    image: certbot/certbot:latest
    volumes:
      - ./certbot/conf/:/etc/letsencrypt/:rw
      - ./certbot/www/:/var/www/certbot/:rw
    networks:
      - lampac-network 
  certbot-renew:
    image: certbot/certbot:latest
    volumes:
      - ./certbot/www/:/var/www/certbot/:rw
      - ./certbot/conf/:/etc/letsencrypt/:rw
    entrypoint: ["/bin/sh", "-c"]
    command: ["while true; do certbot renew --webroot --webroot-path /var/www/certbot/ --quiet && sleep 12h; done"]
    networks:
      - lampac-network
  
networks:  
  lampac-network:  
```

## Create nginx config

```nginx
server {
    listen 80;
    listen [::]:80;

    server_name lampa.home-local.site;
    server_tokens off;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://lampa.home-local.site$request_uri;
    }
}
# Uncomment the lines below after obtaining your SSL certificate.
# server {  
#     listen 443 ssl;  
#     server_name lampa.home-local.site;  
      
#     ssl_certificate /etc/letsencrypt/live/lampa.home-local.site/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/lampa.home-local.site/privkey.pem; 
      
#     location / {  
#         proxy_pass http://lampac:9118;  
#         proxy_set_header Host $host;  
#         proxy_set_header X-Real-IP $remote_addr;  
#         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;  
#         proxy_set_header X-Forwarded-Proto $scheme;  
          
#         # WebSocket support  
#         proxy_http_version 1.1;  
#         proxy_set_header Upgrade $http_upgrade;  
#         proxy_set_header Connection "upgrade";  
#     }  
# }
```

## Run `nginx` and `lampac` server

```bash
docker compose up nginx lampac -d
```

## Get certificate via certbot

```bash
docker compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot/ -d lampa.home-local.site
```

Then uncomment `nginx.conf`

```nginx
server {
    listen 80;
    listen [::]:80;

    server_name lampa.home-local.site;
    server_tokens off;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://lampa.home-local.site$request_uri;
    }
}
server {  
    listen 443 ssl;  
    server_name lampa.home-local.site;  
      
    ssl_certificate /etc/letsencrypt/live/lampa.home-local.site/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/lampa.home-local.site/privkey.pem; 
      
    location / {  
        proxy_pass http://lampac:9118;  
        proxy_set_header Host $host;  
        proxy_set_header X-Real-IP $remote_addr;  
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;  
        proxy_set_header X-Forwarded-Proto $scheme;  
          
        # WebSocket support  
        proxy_http_version 1.1;  
        proxy_set_header Upgrade $http_upgrade;  
        proxy_set_header Connection "upgrade";  
    }  
}
```

## Restart the webserver:

```bash
docker compose down nginx && docker compose up -d nginx
```

