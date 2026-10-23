# step-ca в Docker с ACME

Этот проект разворачивает `step-ca` в Docker через `docker compose` и настраивает получение сертификатов через ACME.

## Структура

- `docker-compose.yaml` — сервис `step-ca` на базе образа `smallstep/step-ca`
- `.env` — переменные окружения для инициализации CA

## Что делает этот стек

- `step-ca` стартует в контейнере и слушает порт `9000`
- Контейнер подключается к внешней Docker-сети `proxy`
- Внутренний алиас `ca.home.local` используется для доступа к CA из сети прокси
- ACME включен через `DOCKER_STEPCA_INIT_ACME=true`

## Переменные окружения

В `.env` установлены ключевые параметры:

- `STEPCA_VERSION` — версия образа `step-ca`
- `DOCKER_STEPCA_INIT_NAME` — название CA
- `DOCKER_STEPCA_INIT_DNS_NAMES` — DNS-имена для CA
- `DOCKER_STEPCA_INIT_REMOTE_MANAGEMENT` — разрешает удаленное управление
- `DOCKER_STEPCA_INIT_ACME` — включает ACME-совместимый интерфейс

## Быстрый старт

1. Убедитесь, что сеть `proxy` существует и в ней работает ваш обратный прокси (например, `traefik`).
2. Запустите контейнер:

```bash
docker compose up -d
```


## Проверка CA и корневого сертификата

После запуска можно извлечь корневой сертификат и установить его на хосте.

```bash
docker compose exec step-ca cat certs/root_ca.crt > /tmp/root_ca.crt
```

docker exec step-ca step ca provisioner add acme --type=ACME --admin-name step --admin-password-file /home/step/secrets/password

Если вы используете Fedora/RHEL/CentOS:

```bash
sudo install -D -m 0644 /tmp/root_ca.crt /etc/pki/ca-trust/source/anchors/root_ca.crt
sudo update-ca-trust
```

Если вы используете Debian/Ubuntu, добавьте сертификат в системное хранилище соответствующим способом.

## Проверка доступности сервиса

Проверьте HTTP/HTTPS доступ к CA:

```bash
curl -v https://ca.home.local:9000/health
```

## Рекомендуемые команды для управления

- `docker compose up -d` — запустить `step-ca`
- `docker compose down` — остановить
- `docker compose logs -f` — следить за логами
- `docker compose exec step-ca bash` — войти в контейнер
- `docker compose exec step-ca cat certs/root_ca.crt > /tmp/root_ca.crt` — экспорт корневого сертификата
- `openssl x509 -in /tmp/root_ca.crt -noout -subject -issuer -dates` — проверить сертификат
- `sudo update-ca-trust` — обновить хранилище доверенных CA (для RPM-систем)

## Пример конфигурации Traefik для ACME

Ниже пример `docker-compose` и динамической конфигурации Traefik, чтобы проксировать `ca.home.local` и получать сертификаты.

Пример статической конфигурации `traefik.yml`:

```yaml
api:
  dashboard: false

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

certificatesResolvers:
  homelab:
    acme:
      caServer: https://ca.home.local:9000/acme/acme/directory
      caCertificates: 
      - /etc/ssl/homelab/root_ca.crt
      storage: /acme/acme.json
      httpChallenge:
        entryPoint: web
```

Пример `docker-compose` для Traefik с сетью `proxy`:

```yaml
services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "80:80"
      - "443:443"
      - "8082:8082"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /tmp/root_ca.crt://etc/ssl/homelab/root_ca.crt:ro
      - ./acme:/acme
      - ./config:/etc/traefik
    networks:
      proxy:
        aliases:
          - traefik.home.local
networks:
  proxy:
    name: proxy
    external: true
```

## Пример меток для `step-ca` и приложений

Если вы хотите, чтобы Traefik автоматически создавал маршруты, добавьте лейблы в `docker-compose.yaml` или в другие сервисы.

Пример меток для `step-ca`:

```yaml
services:
  step-ca:
    image: smallstep/step-ca:${STEPCA_VERSION}
    container_name: step-ca
    ports:
      - "9000:9000"
    env_file:
      - .env
    volumes:
      - step:/home/step
    networks:
      proxy:
        aliases:
          - ca.home.local
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.stepca.rule=Host(`ca.home.local`)"
      - "traefik.http.routers.stepca.entrypoints=websecure"
      - "traefik.http.routers.stepca.tls=true"
      - "traefik.http.routers.stepca.tls.certresolver=le"
```

Пример меток для приложения, получающего сертификаты через ACME:

```yaml
services:
  app:
    image: your-app-image
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.home.local`)"
      - "traefik.http.routers.app.entrypoints=websecure"
      - "traefik.http.routers.app.tls=true"
      - "traefik.http.routers.app.tls.certresolver=le"
```

Для работы ACME через Traefik важно, чтобы:

- `Host` правило соответствовало DNS имени;
- `entryPoints` содержал `web`/`websecure`;
- `certresolver` был указан для HTTPS маршрута.

---

