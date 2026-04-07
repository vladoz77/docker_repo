# 3x-ui + Traefik

Локальная сборка `3x-ui` за `Traefik` с такой схемой:

- панель `3x-ui` открывается на `https://<DOMAIN>/`
- подписки идут через `https://<DOMAIN>/sub/...`
- `VLESS + XHTTP + REALITY` проходит через `Traefik` по `TCP passthrough` на `443`

## Что здесь настроено

`Traefik` слушает:

- `80/tcp` для HTTP challenge и редиректа на HTTPS
- `443/tcp` для панели, подписок и `REALITY`
- `8082/tcp` для метрик

`3x-ui` внутри docker-сети:

- `2053` - панель
- `2096` - subscription server
- `8443` - inbound `VLESS + XHTTP + REALITY`

Наружу порты `2053`, `2096`, `8443` не публикуются. Снаружи открыт только `Traefik`.

## Переменные окружения

Файл [`.env`](./.env):

```env
VERSION="latest"
DOMAIN="vpspl.home-local.site"
XHTTP_REALITY_SNI="www.icloud.com"
EMAIL="you@example.com"
XRAY_VMESS_AEAD_FORCED="false"
XUI_ENABLE_FAIL2BAN="true"
```

Описание:

- `DOMAIN` - домен панели и подписок
- `XHTTP_REALITY_SNI` - SNI, по которому `Traefik` отправляет `REALITY` трафик на backend
- `EMAIL` - email для Let's Encrypt

Важно: `XHTTP_REALITY_SNI` должен совпадать с одним из `serverNames` в `REALITY` inbound внутри `3x-ui`.

## Маршрутизация

### Панель

- внешний адрес: `https://<DOMAIN>/`
- backend: `3x-ui:2053`
- тип роутера: `traefik.http.routers`

### Подписки

- внешний адрес: `https://<DOMAIN>/sub/...`
- backend: `3x-ui:2096`
- тип роутера: `traefik.http.routers`

### VLESS + XHTTP + REALITY

- входящий порт снаружи: `443`
- backend: `3x-ui:8443`
- тип роутера: `traefik.tcp.routers`
- правило: `HostSNI(${XHTTP_REALITY_SNI})`
- режим: `tls.passthrough=true`

Важно: для `REALITY` `Traefik` не маршрутизирует по `/xhttp`. Путь `/xhttp` нужен самому `Xray` и указывается в клиенте, но `Traefik` в этом режиме смотрит только на `SNI`.

## Запуск

```bash
docker compose pull
docker compose up -d
```

Проверка:

```bash
docker compose ps
docker compose logs -f traefik
docker compose logs -f 3x-ui
```

Проверка итогового compose:

```bash
docker compose config
```

## Настройки в 3x-ui

### Панель

Панель должна открываться по:

```text
https://<DOMAIN>/
```

Если после смены домена или прокси появляется ошибка `securecookie: the value is not valid`, очисти cookie для домена панели или открой её в режиме инкогнито.

### Subscription settings

В настройках подписок укажи:

- `URI Path`: `/sub/`
- `Reverse Proxy URI`: `https://<DOMAIN>/sub/`

Тогда ссылки будут генерироваться без внутреннего порта `:2096`.

Пример:

```text
https://vpspl.home-local.site/sub/<token>
```

## Настройки inbound для клиента

Для `VLESS + XHTTP + REALITY` клиенту обычно нужны:

- `address`: IP сервера или домен панели
- `port`: `443`
- `security`: `reality`
- `serverName`: значение из `serverNames`, например `www.icloud.com`
- `transport`: `xhttp`
- `path`: `/xhttp`
- `pbk`: публичный ключ `REALITY`
- `sid`: один из `shortIds`

Важно:

- `serverName` клиента должен совпадать с `XHTTP_REALITY_SNI`, если именно по нему ты маршрутизируешь в `Traefik`
- путь `/xhttp` в клиенте должен совпадать с `xhttpSettings.path` в inbound

## Как понять по логам, что всё работает

Если в debug-логе `Traefik` видно строки вида:

```text
Handling TCP connection address=172.18.0.2:8443
```

это означает, что `Traefik` принял TCP/TLS соединение на `443` и прокинул его на `3x-ui:8443`.

Если в access log видно:

```text
"GET /panel/api/server/status" ... "3x-ui-panel@docker" "http://172.18.0.2:2053"
```

это означает, что панель успешно обслуживается через HTTP router и backend `2053`.

## Частые проблемы

### Панель открывается с 404

Проверь:

- что панель открывается по корню `https://<DOMAIN>/`
- что домен в `.env` совпадает с фактическим доменом
- что `docker compose config` показывает правильный `Host(...)`

### Подписки генерируются с `:2096`

Проверь в `3x-ui`:

- `URI Path = /sub/`
- `Reverse Proxy URI = https://<DOMAIN>/sub/`

### Клиент не подключается по REALITY

Проверь:

- `serverName` клиента совпадает с `XHTTP_REALITY_SNI`
- `XHTTP_REALITY_SNI` совпадает с одним из `serverNames` inbound
- `path` клиента совпадает с `xhttpSettings.path`
- `Traefik` видит соединения и прокидывает их на `8443`

## Примечания

- Панель и подписки работают как HTTP/HTTPS сервисы через `Traefik`
- `REALITY` работает не через `PathPrefix`, а через `TCP passthrough`
- если нужен отдельный публичный путь для панели вроде `/panel`, это лучше делать через middleware reverse proxy, а не рассчитывать на env-переменную внутри `3x-ui`
