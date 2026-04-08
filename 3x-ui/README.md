# 3x-ui + Traefik

Локальная сборка `3x-ui` за `Traefik` с такой схемой:

- панель `3x-ui` открывается на `https://<DOMAIN>/`
- подписки идут через `https://<DOMAIN>/sub/...`
- `trojan + websocket` идёт через `https://<DOMAIN><TROJAN_WS_PATH>`
- `VLESS + XHTTP + REALITY` проходит через `Traefik` по `TCP passthrough` на `443`

## Что здесь настроено

`Traefik` слушает:

- `80/tcp` для HTTP challenge и редиректа на HTTPS
- `443/tcp` для панели, подписок и `REALITY`
- `8082/tcp` для метрик

`3x-ui` внутри docker-сети:

- `2053` - панель
- `2096` - subscription server
- `8444` - inbound `Trojan + WebSocket`
- `8443` - inbound `VLESS + XHTTP + REALITY`

Наружу порты `2053`, `2096`, `8443`, `8444` не публикуются. Снаружи открыт только `Traefik`.

## Переменные окружения

Файл [`.env`](./.env):

```env
VERSION="latest"
DOMAIN="vpspl.home-local.site"
XHTTP_REALITY_SNI="www.icloud.com"
TROJAN_WS_PATH="/trojan-ws"
EMAIL="you@example.com"
XRAY_VMESS_AEAD_FORCED="false"
XUI_ENABLE_FAIL2BAN="true"
```

Описание:

- `DOMAIN` - домен панели и подписок
- `XHTTP_REALITY_SNI` - SNI, по которому `Traefik` отправляет `REALITY` трафик на backend
- `TROJAN_WS_PATH` - публичный path для `trojan + websocket`
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

### Trojan + WebSocket

- внешний адрес: `https://<DOMAIN><TROJAN_WS_PATH>`
- backend: `3x-ui:8444`
- тип роутера: `traefik.http.routers`
- транспорт: WebSocket через HTTP router `Traefik`

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

### Рабочий inbound в 3x-ui

Ниже параметры, которые сработали в UI `3x-ui` для схемы `Traefik -> TCP passthrough -> VLESS + XHTTP + REALITY`.

Базовые поля:

- `Protocol`: `vless`
- `Port`: `8443`
- `Transmission`: `XHTTP`
- `Host`: `<DOMAIN>`
- `Path`: `/xhttp`
- `Mode`: `packet-up`
- `Security`: `Reality`
- `uTLS`: `chrome`

Для `REALITY`:

- `Target`: домен-цель вида `example.com:443`
- `SNI`: тот же домен, что и в `Target`
- `Short IDs`: сгенерированные значения
- `Public Key`: публичный ключ `REALITY`
- `Private Key`: приватный ключ `REALITY`

Важно:

- `Private Key` не хранится в `README`, не публикуется и не коммитится
- `Target` и `SNI` должны быть согласованы между собой
- `Path` должен совпадать с клиентским `xhttp path`

### External Proxy в inbound

В рабочей схеме также был включён `External Proxy`.

Параметры:

- режим: `Same`
- хост: `<DOMAIN>`
- порт: `443`

Смысл этой настройки: inbound внутри `3x-ui` знает, что внешний вход идёт не напрямую на `8443`, а через публичный адрес на `443`, где трафик уже принимает `Traefik`.

Итого получается такая цепочка:

```text
client -> <DOMAIN>:443 -> Traefik (TCP passthrough по SNI) -> 3x-ui:8443
```

### Trojan + WebSocket inbound в 3x-ui

Если нужен дополнительный inbound `trojan + websocket`, можно завести его на внутреннем порту `8444`.

Базовые поля:

- `Protocol`: `trojan`
- `Port`: `8444`
- `Transmission`: `WebSocket`
- `Path`: значение из `TROJAN_WS_PATH`, по умолчанию `/trojan-ws`

Если TLS завершается на `Traefik`, то backend в `3x-ui` обычно оставляют без собственного TLS, а клиент подключается снаружи на `443`.

Итоговая схема:

```text
client -> https://<DOMAIN><TROJAN_WS_PATH> -> Traefik -> 3x-ui:8444
```

## Настройки клиента

Для `VLESS + XHTTP + REALITY` клиенту обычно нужны:

- `address`: IP сервера или домен панели
- `port`: `443`
- `security`: `reality`
- `serverName`: значение из `serverNames` / `SNI` `REALITY`
- `transport`: `xhttp`
- `path`: `/xhttp`
- `pbk`: публичный ключ `REALITY`
- `sid`: один из `shortIds`

Важно:

- `serverName` клиента должен совпадать с тем `SNI`, по которому `Traefik` маршрутизирует `TCP passthrough`
- путь `/xhttp` в клиенте должен совпадать с `xhttpSettings.path` в inbound

Для `trojan + websocket` клиенту обычно нужны:

- `address`: `<DOMAIN>`
- `port`: `443`
- `security`: `tls`
- `network`: `ws`
- `path`: значение из `TROJAN_WS_PATH`
- `password`: пароль клиента `trojan`

Для `v2rayNG`:

- `TLS` должен быть включён
- даже если раздел `TLS` оставить пустым, подключение может работать корректно
- если `TLS` выключен, `trojan + ws` за `Traefik` в этой схеме не заработает

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

### Trojan + WebSocket не подключается

Проверь:

- в клиенте включён `TLS`
- адрес клиента - домен, а не IP
- `path` совпадает с путём inbound, например `/trojan`
- `3x-ui` inbound на `8444` использует `security: none`, если TLS завершается на `Traefik`

Для `v2rayNG` рабочий вариант был таким:

- `TLS` включён
- секция `TLS` оставлена пустой

## Примечания

- Панель и подписки работают как HTTP/HTTPS сервисы через `Traefik`
- `REALITY` работает не через `PathPrefix`, а через `TCP passthrough`
- если нужен отдельный публичный путь для панели вроде `/panel`, это лучше делать через middleware reverse proxy, а не рассчитывать на env-переменную внутри `3x-ui`
