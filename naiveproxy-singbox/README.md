# naiveproxy-singbox

Связка `Caddy` и `sing-box` для запуска `NaiveProxy` через Docker Compose.

`Caddy` принимает HTTPS-трафик на домене, выпускает TLS-сертификаты через ACME и проксирует `CONNECT`-запросы в `sing-box`. Сам `sing-box` поднимает inbound типа `naive` и отдает трафик напрямую через `direct` outbound.

## Как это работает

1. Клиент подключается к домену по HTTPS.
2. `Caddy` завершает TLS.
3. Если запрос имеет метод `CONNECT`, `Caddy` проксирует его в `sing-box` по `h2c://sing-box:1080`.
4. Остальные обычные HTTP-запросы обслуживаются как статическая страница из `caddy/site`.

## Структура проекта

```text
.
├── docker-compose.yaml
├── caddy
│   ├── config
│   │   └── Caddyfile
│   └── site
│       └── index.html
└── sing-box
    ├── config.json
    ├── Dockerfile
    └── entrypoint.sh
```

## Требования

- Docker
- Docker Compose
- Домен, указывающий на сервер
- Открытые порты `80/tcp`, `443/tcp`, `443/udp`

## Переменные окружения

Создай файл `.env` в корне проекта:

```env
DOMAIN=example.com
EMAIL=admin@example.com
PROXY_LOGIN=myuser
PROXY_PASSWORD=mypassword
```

Описание переменных:

- `DOMAIN` - домен, на котором будет доступен сервер
- `EMAIL` - email для ACME-регистрации сертификатов
- `PROXY_LOGIN` - логин для NaiveProxy
- `PROXY_PASSWORD` - пароль для NaiveProxy

## Запуск

Собрать и поднять сервисы:

```bash
docker compose build
docker compose up -d
```

Проверить статус:

```bash
docker compose ps
```

Посмотреть логи:

```bash
docker compose logs -f caddy
docker compose logs -f sing-box
```

## Конфигурация

### Caddy

Файл: [caddy/config/Caddyfile](https://github.com/vladoz77/docker_repo/blob/naiveproxy/naiveproxy-singbox/caddy/config/Caddyfile)

- слушает `{$DOMAIN}`
- автоматически получает TLS-сертификат
- проксирует `CONNECT` в `sing-box:1080`
- отдает заглушку из `/var/www/html`

### sing-box

Файл: [sing-box/config.json](https://github.com/vladoz77/docker_repo/blob/naiveproxy/naiveproxy-singbox/sing-box/config.json)

- inbound типа `naive`
- слушает `0.0.0.0:1080`
- логин и пароль подставляются из `.env`
- логи выводятся в `stderr`

### Кастомный образ sing-box

Файл: [sing-box/Dockerfile](https://github.com/vladoz77/docker_repo/blob/naiveproxy/naiveproxy-singbox/sing-box/Dockerfile)

Используется тонкая обертка над официальным образом `ghcr.io/sagernet/sing-box`:

- ставится `envsubst`
- копируется `entrypoint.sh`
- перед стартом `sing-box` шаблон `config.json` рендерится в итоговый конфиг

Это позволяет хранить логин и пароль в `.env`, а не в готовом JSON-файле.

## Первый запуск на сервере

Для успешного выпуска сертификата должны выполняться все условия:

- `DOMAIN` уже указывает на IP сервера
- порты `80` и `443` доступны из интернета
- на сервере нет другого процесса, который занимает `80/443`

Если DNS еще не обновился, `Caddy` может стартовать, но выпуск сертификата завершится ошибкой ACME. Это нормально до тех пор, пока домен реально не начнет резолвиться на нужный сервер.

## Проверка после деплоя

1. Убедиться, что оба контейнера в статусе `Up`:

```bash
docker compose ps
```

2. Проверить логи `Caddy`:

```bash
docker compose logs --tail=100 caddy
```

В норме там должен появиться успешный выпуск сертификата или хотя бы отсутствие новых ошибок ACME.

3. Проверить логи `sing-box`:

```bash
docker compose logs --tail=100 sing-box
```

4. Открыть в браузере `https://DOMAIN` и убедиться, что заглушка отдается без ошибок сертификата.

## Частые проблемы

### `unknown command "sh" for "sing-box"`

Возникает, если передавать shell-команду в `command`, а базовый образ уже имеет собственный `ENTRYPOINT` на `sing-box`.

В этом проекте проблема решена через кастомный Docker-образ и `entrypoint.sh`.

### ACME challenge `404`

Обычно означает одно из следующего:

- домен указывает не на тот сервер
- трафик на `80/443` не доходит до контейнера
- конфиг `Caddy` не применился после изменений

### Контейнеры поднялись, но клиент не подключается

Проверь:

- корректность `PROXY_LOGIN` и `PROXY_PASSWORD`
- что клиент настроен на домен из `DOMAIN`
- что сертификат действительно выпущен

## Остановка и обновление

Остановить сервисы:

```bash
docker compose down
```

Пересобрать после изменений:

```bash
docker compose build --no-cache sing-box
docker compose up -d
```
