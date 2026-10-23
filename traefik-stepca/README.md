# Traefik + step-ca

Локальная инфраструктура для TLS/HTTPS в homelab на базе:

- Traefik как входная точка и reverse proxy
- smallstep `step-ca` как приватный Certificate Authority
- Docker network `proxy` для изоляции сервисов
- автоматическое получение сертификатов через ACME/HTTP-01

Проект предназначен для внутренней сети: домены типа `*.int.devhomelab.site` и приватный корневой CA.

## Что делает этот стек

- принимает HTTP и HTTPS трафик на `80` и `443`
- автоматически редиректит HTTP -> HTTPS
- получает сертификаты через ACME у внутреннего CA
- маршрутизирует TCP/TLS трафик для `step-ca` через Traefik
- даёт доступ к dashboard Traefik через защищённый Basic Auth

## Архитектура

```text
Internet / LAN
      │
      ├── Traefik (80/443)
      │      ├── HTTP -> HTTPS redirect
      │      ├── ACME challenge on :80
      │      └── TLS dashboard / proxy routes
      │
      └── step-ca (9000)
             └── Internal CA + ACME directory
```

## Компоненты

### `step-ca`
- образ: `smallstep/step-ca`
- инициализируется через `DOCKER_STEPCA_INIT_*`
- создаёт внутреннюю CA и ACME endpoint
- работает в сети `proxy` с фиксированным IP
- хранит сертификаты и ключи в Docker volume `step-ca-data`

### `traefik`
- образ: `traefik`
- настроен для Docker provider
- слушает порты `80`, `443` и `8082`
- использует `certificatesResolvers.homelab`
- заходит в dashboard по адресу `https://dashboard.int.devhomelab.site`
- подключён к внешней сети `proxy`

## Структура проекта

```text
traefik-stepca/
├── .env-example
├── config/
│   └── traefik.yml
├── docker-compose.yaml
├── README.md
└── acme/
```

## Требования

- Docker Engine
- Docker Compose v2
- внешняя сеть Docker: `proxy`
- корректный DNS / hosts для доменов:
  - `ca.int.devhomelab.site`
  - `dashboard.int.devhomelab.site`

Создать сеть при необходимости:

```bash
docker network create proxy
```

## Подготовка окружения

Скопируйте пример `.env`:

```bash
cp .env-example .env
```

Пример содержимого `.env-example`:

```env
DOCKER_NETWORK=proxy
DOCKER_VOLUME_NAME=step-ca-data

STEPCA_VERSION=latest
STEPCA_CONTAINER_NAME=step-ca
STEPCA_STATIC_IP=192.168.200.254
STEPCA_NAME=Homelab CA
STEPCA_DNS_NAMES=ca.int.devhomelab.site,localhost,step-ca

TRAEFIK_VERSION=latest
TRAEFIK_CONTAINER_NAME=traefik
TRAEFIK_STATIC_IP=192.168.200.253
TRAEFIK_BIND_IP=10.10.0.254
```

### Важные параметры

- `STEPCA_DNS_NAMES` — список DNS, которые будут использоваться для CA
- `TRAEFIK_BIND_IP` — IP, на котором Traefik открывает `80` и `443`
- `STEPCA_STATIC_IP` и `TRAEFIK_STATIC_IP` — фиксированные адреса внутри сети `proxy`
- Traefik обращается к внутреннему ACA по адресу:
  `https://ca.int.devhomelab.site:9000/acme/acme/directory`

## Запуск

Проверить корректность compose-файла:

```bash
docker compose --env-file .env-example config
```

Запустить стек:

```bash
docker compose up -d
```

Проверить состояние:

```bash
docker compose ps
```

Просмотреть логи:

```bash
docker compose logs -f
```

Проверить healthcheck для `step-ca`:

```bash
docker inspect --format='{{json .State.Health}}' step-ca
```

## Доступ к сервисам

После запуска доступны:

- Internal CA: `https://ca.int.devhomelab.site`
- Traefik dashboard: `https://dashboard.int.devhomelab.site`
- Prometheus metrics: `http://127.0.0.1:8082`

## Конфигурация Traefik

Файл конфигурации: `config/traefik.yml`

Содержит:

- HTTP -> HTTPS redirect
- entrypoints `web` и `websecure`
- Docker provider с `exposedByDefault: false`
- ACME resolver `homelab`
- metrics endpoint на `:8082`

## Полезные команды

```bash
docker compose up -d --force-recreate

docker compose logs step-ca
docker compose logs traefik

docker compose down
```

## Устранение неполадок

### 1. Traefik не получает сертификаты

Проверьте:

1. существует ли сеть `proxy`
2. контейнер `step-ca` в статусе `healthy`
3. корректность DNS / hosts для доменов
4. доступность `https://ca.int.devhomelab.site` из сети

### 2. Docker Compose не запускается

Проверьте переменные окружения и синтаксис файла:

```bash
docker compose --env-file .env-example config
```

Если команда падает — проверьте значения `STEPCA_*` и `TRAEFIK_*`.

### 3. Dashboard недоступен

Проверьте:

- что Traefik запущен и healthy
- что домен `dashboard.int.devhomelab.site` резолвится
- что TLS certificate resolver настроен корректно

## Безопасность

- Dashboard Traefik защищён Basic Auth.
- Корневой CA и сертификаты находятся в локальной приватной сети.
- Для production/открытого доступа не используйте `latest` теги и не открывайте dashboard/CA напрямую без ограничения доступа.
- Смените стандартные учётные данные после первого запуска.

## Примечание

Этот проект ориентирован на локальный homelab / внутреннюю инфраструктуру. Для публичного окружения или production нужно дополнительно:

- использовать внешне валидный домен и публичный ACME
- хранить секреты в безопасном менеджере
- зафиксировать версии образов вместо `latest`
- ограничить доступ к dashboard и CA интерфейсам по сетевым правилам

## Быстрый старт

```bash
docker network create proxy
cp .env-example .env
docker compose up -d
```

После этого можно открыть:

- `https://ca.int.devhomelab.site`
- `https://dashboard.int.devhomelab.site`
