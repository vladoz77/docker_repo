## Create certificate for proxy

1. **Create CA key and certificate**
    ```bash
    openssl genrsa -out ca.key 2048
    openssl req -new -x509 -days 365 -key ca.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=Acme Root CA" -out ca.crt
    ```
2. **Create server key and server.csr**
    ```bash
    openssl req -newkey rsa:2048 -nodes -keyout nexus.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=*.home.local" -out nexus.csr
    ```
3. **Create server certificate**
    ```bash
    openssl x509 -req -extfile <(printf "subjectAltName=DNS:nexus.home.local,DNS:docker.home.local, DNS:proxy.home.local, IP:127.0.0.1, IP:172.24.0.1, IP:10.84.62.10") -days 365 -in nexus.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out nexus.crt
    ```
