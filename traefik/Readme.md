# Traefik Reverse Proxy with Docker Compose

Локальный проект обратного прокси на Traefik с Docker Compose и интеграцией с step-ca.

## Структура проекта

```
├── .env                   # Переменные окружения для docker-compose и скрипта
├── acme/                  # Хранение файла acme.json для ACME resolver
├── config/                # Сгенерированная статическая конфигурация Traefik
│   └── traefik.yml
├── docker-compose.yaml    # Основной compose-файл для Traefik
├── down.sh                # Скрипт остановки и очистки конфигурации
├── templates/             # Шаблоны для генерации Traefik конфигурации
│   └── traefik.yml.tmpl
├── up.sh                  # Скрипт генерации конфигурации и запуска Traefik
└── Readme.md              # Документация
```

## Предварительные требования

- Docker
- Docker Compose
- jq
- curl
- step-ca

## Настройка `.env`

Файл `.env` содержит основные переменные:

```ini
TRAEFIK_VERSION=v3.7.7
TRAEFIK_ACME_SERVER=https://ca.home.local:9000/acme/acme/directory
TRAEFIK_CACERTIFICATE=/etc/ssl/homelab/root_ca.crt
TRAEFIK_DASHBOARD_URL=traefik.home.local
TRAEFIK_STATIC_IP=192.168.200.254

DOCKER_CONTAINER_NAME=traefik
DOCKER_NETWORK=proxy
DOCKER_SUBNET=192.168.200.0/24
DOCKER_GATEWAY=192.168.200.1

ROOT_CA_DIR=/tmp/root_ca.crt
```

- `TRAEFIK_ACME_SERVER` — адрес ACME сервера step-ca.
- `TRAEFIK_CACERTIFICATE` — путь к корневому сертификату внутри контейнера.
- `ROOT_CA_DIR` — путь к локальному корневому сертификату на хосте.
- `DOCKER_NETWORK`/`DOCKER_SUBNET`/`DOCKER_GATEWAY` — создаваемая внешняя сеть.

## Что делает `up.sh`

Скрипт `up.sh`:

- проверяет наличие файла `.env`
- загружает переменные окружения
- тестирует доступность `step-ca` по `https://localhost:9000/health`
- проверяет наличие корневого сертификата `ROOT_CA_DIR`
- генерирует `./config/traefik.yml` из шаблона `./templates/traefik.yml.tmpl`
- создаёт `./acme/acme.json`, если нужно
- создаёт Docker-сеть, если её нет
- стартует Traefik через `docker compose up -d`

## Docker Compose

`docker-compose.yaml` создаёт сервис Traefik:

- пробрасывает порты 80, 443, 8082
- монтирует `/var/run/docker.sock`
- монтирует `./acme` и `./config`
- подключается к внешней сети `traefik-net` (имя из переменной `DOCKER_NETWORK`)
- включает Docker labels для dashboard

## Статическая конфигурация Traefik

`templates/traefik.yml.tmpl` описывает статическую конфигурацию:

- `entryPoints` для `web`, `websecure` и `metrics`
- `providers.docker`
- `certificatesResolvers.homelab` с ACME и `caCertificates`

После запуска `up.sh` файл становится доступен в `config/traefik.yml`.

## ACME и сертификаты

- `acme.json` хранится в каталоге `./acme`
- `traefik.yml.tmpl` использует `TRAEFIK_ACME_SERVER` и `TRAEFIK_CACERTIFICATE`
- корневой сертификат монтируется в контейнер из `ROOT_CA_DIR`

## Панель управления Traefik

Dashboard доступен по адресу:

```text
https://dashboard.home.local
```

> Убедитесь, что `dashboard.home.local` резолвится в `192.168.200.254` или другой IP-адрес внутри вашей сети.

## Запуск и остановка

```bash
./up.sh
./down.sh
```

Если вы хотите запустить напрямую через Docker Compose:

```bash
docker compose up -d
```

Для остановки:

```bash
docker compose down
```

## Примечания

- Проект ориентирован на локальную сеть и тестовую среду.
- В production используйте доверенные сертификаты и надёжную DNS-конфигурацию.
- `step-ca` должен быть доступен и отвечать на health-запрос перед запуском `up.sh`.
