1. Создаем root ca

```bash
# Создаем приватный ключ для CA
openssl genrsa -out ca.key 2048

# Создаем корневой сертификат CA
openssl req -new -x509 -key ca.key -out ca.crt -days 3650 \
  -subj "/C=RU/ST=Russia/L=Ryazan/O=Home-Lab/OU=IT/CN=Elasticsearch CA"
```

2. Создание сертификата для узла Elasticsearch

```bash
openssl genrsa -out es.key 2048

cat > es.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = RU
ST = Russia
L = Ryazan
O = Home-Lab
OU = IT
CN = es.home.local

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = es.home.local
DNS.3 = es
DNS.4 = es1
DNS.5 = es2
DNS.6 = es3
DNS.7 = es1.home.local
DNS.8 = es2.home.local
DNS.9 = es3.home.local
DNS.10 = es-service
IP.1 = 127.0.0.1
EOF

# Создаем запрос на сертификат
openssl req -new -key es.key -out es.csr -config es.cnf

# Создаем сертифкат узла
openssl x509 -req -in es.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out es.crt -days 365 -extensions v3_req -extfile es.cnf
```

3. Проверка сертификатов

```bash
openssl x509 -in es.crt -text -noout
```