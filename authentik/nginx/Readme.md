# Create self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout authentik.key -out authentik.crt