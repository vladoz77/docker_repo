### Структура проекта

```bash
elasticsearch-cluster/
├── docker-compose.yml
├── .env
├── certs/
│   ├── ca.crt
│   ├── ca.key
│   ├── es.crt
│   └── es.key
├── config/
│   └── init-users.sh
└── README.md
```

### Подготовка окружения

```bash
mkdir elasticsearch-cluster
cd elasticsearch-cluster
mkdir certs config
```

Создайте файл `.env`:

```bash
cat > .env << EOF
CLUSTER_NAME=es-docker-cluster
ELASTIC_PASSWORD=password
KIBANA_PASSWORD=password
MEM_LIMIT=2g
LICENSE=basic
EOF
```

### Генерация SSL сертификатов

#### Создание корневого CA

```bash
# Создаем приватный ключ для CA
openssl genrsa -out certs/ca.key 2048

# Создаем корневой сертификат CA
openssl req -new -x509 -key certs/ca.key -out certs/ca.crt -days 3650 \
  -subj "/C=RU/ST=Russia/L=Ryazan/O=Home-Lab/OU=IT/CN=Elasticsearch CA"
```

### Создание сертификата для узлов Elasticsearch

```bash
# Создаем приватный ключ для узла
openssl genrsa -out certs/es.key 2048

# Создаем конфигурационный файл для сертификата
cat > certs/es.cnf << EOF
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
CN = es.cluster.local

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = es.cluster.local
DNS.3 = es
DNS.4 = es01
DNS.5 = es02
DNS.6 = es03
DNS.7 = es01.cluster.local
DNS.8 = es02.cluster.local
DNS.9 = es03.cluster.local
DNS.10 = es-service
IP.1 = 127.0.0.1
EOF

# Создаем запрос на сертификат
openssl req -new -key certs/es.key -out certs/es.csr -config certs/es.cnf

# Создаем сертификат узла
openssl x509 -req -in certs/es.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial \
  -out certs/es.crt -days 365 -extensions v3_req -extfile certs/es.cnf

# Очищаем временные файлы
rm certs/es.csr certs/es.cnf
```

### Создание скрипта инициализации

Создайте `config/init-users.sh`:

```bash
#!/bin/bash

set -e

echo "Waiting for Elasticsearch availability..."
until curl -s --cacert /usr/share/elasticsearch/config/certs/ca.crt https://es01:9200 | grep -q "missing authentication credentials"; do
    echo "Elasticsearch not ready, waiting..."
    sleep 10
done

echo "Elasticsearch is ready! Setting kibana_system password..."

until curl -s -o /dev/null -w "%{http_code}" -X POST "https://es01:9200/_security/user/kibana_system/_password" \
    --cacert /usr/share/elasticsearch/config/certs/ca.crt \
    -u "elastic:${ELASTIC_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q "200"; do 
  echo "Failed to set kibana_system password, retrying..."
  sleep 10 
done

echo "kibana_system password set successfully!"

echo "Creating user vlad..."

until curl -s -o /dev/null -w "%{http_code}" -X PUT "https://es01:9200/_security/user/vlad" \
    --cacert /usr/share/elasticsearch/config/certs/ca.crt \
    -u "elastic:${ELASTIC_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d '{
      "password" : "password",
      "roles" : [ "editor" ],
      "full_name" : "Kovalev Vlad",
      "email" : "vladoz77@yandex.ru",
      "metadata" : {
        "intelligence" : 7
      },
      "enabled": true
    }' | grep -q "200"; do
  echo "Failed to create user vlad, retrying..."
  sleep 10
done

echo "User vlad created successfully!"
echo "All initialization completed!"
```

Сделайте скрипт исполняемым:

```bash
chmod +x config/init-users.sh
```

### Создание docker-compose.yml

Создайте `docker-compose.yml` с содержимым

```yaml
services:
  setup:
    image: docker.elastic.co/elasticsearch/elasticsearch:9.2.0
    container_name: setup_es
    environment:
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
      - KIBANA_PASSWORD=${KIBANA_PASSWORD}
    volumes:
     - ./certs:/usr/share/elasticsearch/config/certs
     - ./config/init-users.sh:/usr/share/elasticsearch/config/init-users.sh
    command: ["/bin/sh", "/usr/share/elasticsearch/config/init-users.sh"]
    healthcheck:
      test: ["CMD-SHELL", "[ -f /usr/share/elasticsearch/config/init-users.sh ]"]
      interval: 1s
      timeout: 5s
      retries: 120
    networks:
      es-net:

  es01:
    image: docker.elastic.co/elasticsearch/elasticsearch:9.2.0
    container_name: es01
    volumes:
      - ./certs:/usr/share/elasticsearch/config/certs
      # - ./config/elasticsearch.yaml:/usr/share/elasticsearch/config/elasticsearch.yml
      - esdata01:/usr/share/elasticsearch/data
    ports:
      - 9200:9200
    environment:
      - node.name=es01
      - cluster.name=${CLUSTER_NAME}
      - cluster.initial_master_nodes=es01,es02,es03
      - discovery.seed_hosts=es02,es03
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      # ssl config
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=true
      - xpack.security.http.ssl.key=certs/es.key
      - xpack.security.http.ssl.certificate=certs/es.crt
      - xpack.security.http.ssl.certificate_authorities=certs/ca.crt
      - xpack.security.transport.ssl.enabled=true
      - xpack.security.transport.ssl.key=certs/es.key
      - xpack.security.transport.ssl.certificate=certs/es.crt
      - xpack.security.transport.ssl.certificate_authorities=certs/ca.crt
      - xpack.security.transport.ssl.verification_mode=certificate
      - xpack.license.self_generated.type=${LICENSE}
      - xpack.ml.use_auto_machine_memory_percent=true
    mem_limit: ${MEM_LIMIT}
    ulimits:
      memlock:
        soft: -1
        hard: -1
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "curl -s --cacert config/certs/ca.crt https://localhost:9200 | grep -q 'missing authentication credentials'",
        ]
      interval: 10s
      timeout: 10s
      retries: 120
    networks:
      es-net:

  es02:
    depends_on:
      - es01
    image: docker.elastic.co/elasticsearch/elasticsearch:9.2.0
    container_name: es02
    volumes:
      - ./certs:/usr/share/elasticsearch/config/certs
      # - ./config/elasticsearch.yaml:/usr/share/elasticsearch/config/elasticsearch.yml
      - esdata02:/usr/share/elasticsearch/data
    environment:
      - node.name=es02
      - cluster.name=${CLUSTER_NAME}
      - cluster.initial_master_nodes=es01,es02,es03
      - discovery.seed_hosts=es01,es03
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      # ssl config
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=true
      - xpack.security.http.ssl.key=certs/es.key
      - xpack.security.http.ssl.certificate=certs/es.crt
      - xpack.security.http.ssl.certificate_authorities=certs/ca.crt
      - xpack.security.transport.ssl.enabled=true
      - xpack.security.transport.ssl.key=certs/es.key
      - xpack.security.transport.ssl.certificate=certs/es.crt
      - xpack.security.transport.ssl.certificate_authorities=certs/ca.crt
      - xpack.security.transport.ssl.verification_mode=certificate
      - xpack.license.self_generated.type=${LICENSE}
      - xpack.ml.use_auto_machine_memory_percent=true
    mem_limit: ${MEM_LIMIT}
    ulimits:
      memlock:
        soft: -1
        hard: -1
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "curl -s --cacert config/certs/ca.crt https://localhost:9200 | grep -q 'missing authentication credentials'",
        ]
      interval: 10s
      timeout: 10s
      retries: 120
    networks:
      es-net:

  es03:
    depends_on:
      - es02
    image: docker.elastic.co/elasticsearch/elasticsearch:9.2.0
    container_name: es03
    volumes:
      - ./certs:/usr/share/elasticsearch/config/certs
      # - ./config/elasticsearch.yaml:/usr/share/elasticsearch/config/elasticsearch.yml
      - esdata03:/usr/share/elasticsearch/data
    environment:
      - node.name=es03
      - cluster.name=${CLUSTER_NAME}
      - cluster.initial_master_nodes=es01,es02,es03
      - discovery.seed_hosts=es02,es01
      - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      # ssl config
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=true
      - xpack.security.http.ssl.key=certs/es.key
      - xpack.security.http.ssl.certificate=certs/es.crt
      - xpack.security.http.ssl.certificate_authorities=certs/ca.crt
      - xpack.security.transport.ssl.enabled=true
      - xpack.security.transport.ssl.key=certs/es.key
      - xpack.security.transport.ssl.certificate=certs/es.crt
      - xpack.security.transport.ssl.certificate_authorities=certs/ca.crt
      - xpack.security.transport.ssl.verification_mode=certificate
      - xpack.license.self_generated.type=${LICENSE}
      - xpack.ml.use_auto_machine_memory_percent=true
    mem_limit: ${MEM_LIMIT}
    ulimits:
      memlock:
        soft: -1
        hard: -1
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "curl -s --cacert config/certs/ca.crt https://localhost:9200 | grep -q 'missing authentication credentials'",
        ]
      interval: 10s
      timeout: 10s
      retries: 120
    networks:
      es-net:

  kibana:
    depends_on:
      es01:
        condition: service_healthy
      es02:
        condition: service_healthy
      es03:
        condition: service_healthy
    image: docker.elastic.co/kibana/kibana:9.2.0
    container_name: kibana
    volumes:
      - ./certs:/usr/share/kibana/config/certs
      - kibanadata:/usr/share/kibana/data
    ports:
      - 5601:5601
    environment:
      - SERVERNAME=kibana
      - ELASTICSEARCH_HOSTS=https://es01:9200
      - ELASTICSEARCH_USERNAME=kibana_system
      - ELASTICSEARCH_PASSWORD=${KIBANA_PASSWORD}
      - ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES=config/certs/ca.crt
    mem_limit: ${MEM_LIMIT}
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "curl -s -I http://localhost:5601 | grep -q 'HTTP/1.1 302 Found'",
        ]
      interval: 10s
      timeout: 10s
      retries: 120
    networks:
      es-net:

volumes:
  esdata01:
  esdata02:
  esdata03:
  kibanadata:

networks:
  es-net:
```

### Запуск кластера

```bash
# Запуск Elasticsearch узлов
docker compose up -d 

# Ожидание готовности узлов
docker compose ps

# Проверка логов инициализации
docker compose logs setup -f

# Проверка статуса Kibana
docker compose logs kibana -f
```

### Проверка кластера Elasticsearch

```bash
# Проверка здоровья кластера
curl -s -u elastic:password --cacert certs/ca.crt https://localhost:9200/_cluster/health | jq
{
  "cluster_name": "es-docker-cluster",
  "status": "green",
  "timed_out": false,
  "number_of_nodes": 3,
  "number_of_data_nodes": 3,
  "active_primary_shards": 39,
  "active_shards": 78,
  "relocating_shards": 0,
  "initializing_shards": 0,
  "unassigned_shards": 0,
  "unassigned_primary_shards": 0,
  "delayed_unassigned_shards": 0,
  "number_of_pending_tasks": 0,
  "number_of_in_flight_fetch": 0,
  "task_max_waiting_in_queue_millis": 0,
  "active_shards_percent_as_number": 100.0
}

# Проверка списка узлов
curl -s -u elastic:password --cacert certs/ca.crt https://localhost:9200/_cat/nodes?v

ip         heap.percent ram.percent cpu load_1m load_5m load_15m node.role   master name
172.19.0.4           26          75   8    1.70    2.58     2.36 cdfhilmrstw *      es02
172.19.0.5           61          62   8    1.70    2.58     2.36 cdfhilmrstw -      es03
172.19.0.3           77          73   8    1.70    2.58     2.36 cdfhilmrstw -      es01

# Проверка пользователей
url -s -u elastic:password --cacert certs/ca.crt https://localhost:9200/_security/user | jq
{
  "elastic": {
    "username": "elastic",
    "roles": [
      "superuser"
    ],
    "full_name": null,
    "email": null,
    "metadata": {
      "_reserved": true
    },
    "enabled": true
  },
  "kibana": {
    "username": "kibana",
    "roles": [
      "kibana_system"
    ],
    "full_name": null,
    "email": null,
    "metadata": {
      "_deprecated_reason": "Please use the [kibana_system] user instead.",
      "_reserved": true,
      "_deprecated": true
    },
    "enabled": true
  },
  "kibana_system": {
    "username": "kibana_system",
    "roles": [
      "kibana_system"
    ],
    "full_name": null,
    "email": null,
    "metadata": {
      "_reserved": true
    },
    "enabled": true
  },
  "logstash_system": {
    "username": "logstash_system",
    "roles": [
      "logstash_system"
    ],
    "full_name": null,
    "email": null,
    "metadata": {
      "_reserved": true
    },
    "enabled": true
  },
  "beats_system": {
    "username": "beats_system",
    "roles": [
      "beats_system"
    ],
    "full_name": null,
    "email": null,
    "metadata": {
      "_reserved": true
    },
    "enabled": true
  },
  "apm_system": {
    "username": "apm_system",
    "roles": [
      "apm_system"
    ],
    "full_name": null,
    "email": null,
    "metadata": {
      "_reserved": true
    },
    "enabled": true
  },
  "remote_monitoring_user": {
    "username": "remote_monitoring_user",
    "roles": [
      "remote_monitoring_collector",
      "remote_monitoring_agent"
    ],
    "full_name": null,
    "email": null,
    "metadata": {
      "_reserved": true
    },
    "enabled": true
  },
  "vlad": {
    "username": "vlad",
    "roles": [
      "editor"
    ],
    "full_name": "Kovalev Vlad",
    "email": "vladoz77@yandex.ru",
    "metadata": {
      "intelligence": 7
    },
    "enabled": true
  }
}

```

### Проверка Kibana

```bash
# Проверка доступности Kibana
curl -s -I http://localhost:5601 | head -n 1

# Проверка в браузере
echo "Откройте в браузере: http://localhost:5601"
echo "Логин: vlad"
echo "Пароль: password"
```

### Мониторинг состояния

```bash
# Просмотр логов
docker compose logs -f es01
docker compose logs -f kibana

# Проверка использования ресурсов
docker compose stats
CONTAINER ID   NAME      CPU %     MEM USAGE / LIMIT   MEM %     NET I/O           BLOCK I/O        PIDS
763150b33c27   kibana    0.44%     675.9MiB / 2GiB     33.00%    3.85MB / 10.8MB   15.6MB / 258kB   12
0b2dded74799   es03      1.22%     1.246GiB / 2GiB     62.28%    2.05MB / 6.31MB   3.73MB / 211MB   129
93424f518bf6   es02      1.07%     1.441GiB / 2GiB     72.03%    6.75MB / 11MB     19.3MB / 301MB   166
542f573e097d   es01      0.85%     1.447GiB / 2GiB     72.35%    25.2MB / 9.96MB   23.9MB / 293MB   157

```


### Настройка реверс-прокси `traefik` для доступа к `kibana`

Создадим самоподписываемые сертификаты для зоны `*.home.local.`

```bash
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/local.key -out certs/local.crt \
  -subj "/CN=*.home.local"
```

Создадим файл с конфигурацией  `tls.yaml`

```yaml
mkdir -p dynamic
cat > dynamic/tls.yml << EOF
tls:
  certificates:
    - certFile: /certs/local.crt
      keyFile: /certs/local.key
EOF
```

Создадим пароль для дашборда

```bash
htpasswd -nb admin "P@ssw0rd" | sed -e 's/\$/\$\$/g'
```

Создадим `docker-compose.yaml`с конфигурацией траефика

```bash
services:
  traefik:
    image: traefik:v3.4
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true

    networks:
     # Connect to the 'traefik_proxy' overlay network for inter-container communication across nodes
      - proxy

    ports:
      - "80:80"
      - "443:443"
      - "8082:8082"

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./certs:/certs:ro
      - ./config:/config:ro

    command:
      # EntryPoints
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.websecure.http.tls=true"
      - "--metrics.prometheus.entrypoint=metrics"
      

      # Attach the static configuration tls.yaml file that contains the tls configuration settings
      - "--providers.file.filename=/config/tls.yaml"

      # Providers 
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=proxy"

      # API & Dashboard 
      - "--api.dashboard=true"
      - "--api.insecure=false"

      # Observability 
      - "--log.level=INFO"
      - "--accesslog=true"
      - "--metrics.prometheus=true"
      - "--entrypoints.metrics.address=:8082"
      

  # Traefik Dynamic configuration via Docker labels
    labels:
      # Enable self‑routing
      - "traefik.enable=true"

      # Dashboard router
      - "traefik.http.routers.dashboard.rule=Host(`traefik.home.local`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.tls=true"

      # Basic‑auth middleware
      - "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:$$apr1$$9Bf7fi7r$$4SZtA20rXAYDxGWvP8jFM0"
      - "traefik.http.routers.dashboard.middlewares=dashboard-auth@docker"

networks:
  proxy:
    name: proxy
```

Изменим конфигурацию `kibana` в docker-compose

```yaml
# ... существующие сервисы Elasticsearch
--- 
kibana:
    depends_on:
      es01:
        condition: service_healthy
      es02:
        condition: service_healthy
      es03:
        condition: service_healthy
    image: docker.elastic.co/kibana/kibana:9.2.0
    container_name: kibana
    volumes:
      - ./certs:/usr/share/kibana/config/certs
      - kibanadata:/usr/share/kibana/data
    ports:
      - 5601:5601
    environment:
      - SERVERNAME=kibana
      - SERVER_HOST=0.0.0.0
      - ELASTICSEARCH_HOSTS=https://es01:9200
      - ELASTICSEARCH_USERNAME=kibana_system
      - ELASTICSEARCH_PASSWORD=${KIBANA_PASSWORD}
      - ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES=config/certs/ca.crt
    mem_limit: ${MEM_LIMIT}
    labels:
    # Добавим настройки траефика
      - "traefik.enable=true"
      - "traefik.http.routers.kibana.rule=Host(`kibana.home.local`)"
      - "traefik.http.routers.kibana.entrypoints=websecure"
      - "traefik.http.routers.kibana.tls=true"
      - "traefik.http.services.kibana.loadbalancer.server.port=5601"
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "curl -s -I http://localhost:5601 | grep -q 'HTTP/1.1 302 Found'",
        ]
      interval: 10s
      timeout: 10s
      retries: 120
    networks:
      es-net:
      proxy: # ← Добавим сеть траефик
```

Так же в файл `/etc/hosts` нужно добавить имена хостов (На продакшене добавляем в днс серевер)

```bash
10.84.62.52 traefik.home.local kibana.home.local
```

Запустим все наши сервисы командой

```bash
docker compose up -d
```

Проверить можно зайдя в браузер и набрать `https://kibana.home.local`