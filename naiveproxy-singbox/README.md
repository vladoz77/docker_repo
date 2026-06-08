# naiveproxy-singbox

Связка `Caddy` и `sing-box` для запуска `NaiveProxy` через Docker Compose.

`Caddy` принимает HTTPS-трафик на домене, выпускает TLS-сертификаты через ACME и проксирует `CONNECT`-запросы в `sing-box`. Сам `sing-box` поднимает inbound типов `naive` и `hysteria2` и отдает трафик напрямую через `direct` outbound.

## Как это работает

1. Клиент подключается к домену по HTTPS.
2. `Caddy` завершает TLS.
3. Для HTTPS-прокси `CONNECT` приходит с `:authority` целевого хоста, например `ya.ru:443`, поэтому `Caddy` должен слушать не только `https://DOMAIN`, но и `:443`.
4. Если запрос имеет метод `CONNECT`, `Caddy` проксирует его в `sing-box` по `h2c://sing-box:1080`.
5. Остальные обычные HTTP-запросы обслуживаются как статическая страница из `caddy/site`.

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
- `PROXY_LOGIN` - логин для NaiveProxy и имя пользователя для Hysteria2
- `PROXY_PASSWORD` - пароль для NaiveProxy и Hysteria2

Сгенерируй логин и пароль:

```sh
echo "Логин:  $(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 16)"
echo "Пароль: $(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 24)"
```

После этого вставь значения в `.env`.

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
- также принимает `CONNECT` на `:443`, чтобы запросы с `:authority` вида `example.org:443` не отбрасывались роутером
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
## Клиенты и подключение

### NaiveProxy (TCP порт 1080)

```
naive://user:password@example.com:1080
```

Клиенты: [nekoray](https://github.com/MatsuriDayo/nekoray), [sing-box-cli](https://github.com/SagerNet/sing-box)

### Hysteria2 (UDP порт 443)

```
hysteria://myuser:mypassword@example.com:443
```

**Особенности:**
- Имя пользователя для Hysteria2 берется из `PROXY_LOGIN`

- Работает через **UDP 443** (совместимо с TCP 443 Caddy)
- Обфускация трафика (**Salamander**)
- Высокая пропускная способность (до 1000 Mbps)
- Маскируется под HTTPS к вашему домену

Клиенты: [sing-box-cli](https://github.com/SagerNet/sing-box), [hiddify-next](https://github.com/hiddify/hiddify-next)

## Конфигурация sing-box

sing-box поддерживает два типа inbound:

### 1. NaiveProxy (TCP 1080)

```json
{
  "type": "naive",
  "tag": "naive-in",
  "network": "tcp",
  "listen": "0.0.0.0",
  "listen_port": 1080,
  "users": [
    {
      "username": "${PROXY_LOGIN}",
      "password": "${PROXY_PASSWORD}"
    }
  ]
}
```

### 2. Hysteria2 (UDP 443)

```json
{
  "type": "hysteria2",
  "tag": "hysteria2-in",
  "listen": "0.0.0.0",
  "listen_port": 443,
  "up_mbps": 1000,
  "down_mbps": 1000,
  "obfs": {
    "type": "salamander",
    "password": "${PROXY_PASSWORD}"
  },
  "users": [
    {
      "name": "${PROXY_LOGIN}",
      "password": "${PROXY_PASSWORD}"
    }
  ],
  "masquerade": {
    "type": "proxy",
    "url": "https://${DOMAIN}",
    "rewrite_host": true
  }
}
```

## Безопасность

1. Изменить логин и пароль в `.env` на надежные значения
2. Hysteria2 использует обфускацию **Salamander** для скрытия протокола
3. Весь трафик шифруется (TLS для Caddy, QUIC для Hysteria2)
4. Оба протокола маскируются под обычный HTTPS трафик
4. Открыть в браузере `https://DOMAIN` и убедиться, что заглушка отдается без ошибок сертификата.

## Настройка клиента sing-box

Для подключения к этому серверу удобнее всего использовать `sing-box` как клиент с outbound типа `naive`.

Ниже пример клиентского конфига, который поднимает локальный proxy на `127.0.0.1:2080` и отправляет трафик на ваш сервер:

```json
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 2080
    }
  ],
  "outbounds": [
    {
      "type": "naive",
      "tag": "naive-out",
      "server": "example.com",
      "server_port": 443,
      "username": "myuser",
      "password": "mypassword",
      "tls": {
        "enabled": true,
        "server_name": "example.com"
      }
    }
  ],
  "route": {
    "final": "naive-out"
  }
}
```

Что заменить:

- `example.com` на значение `DOMAIN`
- `myuser` на `PROXY_LOGIN`
- `mypassword` на `PROXY_PASSWORD`

> Можно также использовать короткую строку подключения в формате:
>
> `naive+https://LOGIN:PASSWORD@DOMAIN:443`
>
> например:
>
> `naive+https://b1ZFXtzE1CWkQ7DS:IZA7lUwPedtttXcZggq7MMA1@vps.devhomelab.site:443`

Сохранить конфиг, например, как `client.json`, затем запустить:

```bash
sing-box run -c client.json
```

После запуска локальный proxy будет доступен на `127.0.0.1:2080`.

Можно использовать его в браузере, в системе или проверить через `curl`:

```bash
curl -v --proxy http://127.0.0.1:2080 https://ya.ru
```

Если нужен только SOCKS5, можно заменить inbound `mixed` на `socks`.

Важно: `curl --proxy-http2 --proxy https://DOMAIN:443` проверяет обычный HTTPS proxy, но не `naive`-протокол напрямую. Для этого сервера корректная проверка идет через клиент `sing-box` с outbound типа `naive`.


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
