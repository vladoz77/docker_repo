# NaiveProxy через Caddy в Docker Compose

Этот репозиторий поднимает `NaiveProxy` на базе `Caddy` и плагина `forwardproxy` в Docker. 

## Что внутри

- `Dockerfile` собирает `caddy` с naive-плагином
- `Docker-compose.yaml` запускает контейнер, пробрасывает порты и сохраняет сертификаты
- `config/Caddyfile` содержит конфиг `Caddy`
- `site/index.html` это простая страница-заглушка
- `.env` хранит домен, почту и учетные данные прокси

## Подготовка хоста

### 1. Домен

Домен должен указывать на IP этого сервера. До запуска проверь DNS:

```sh
dig +short your.domain.com
```

### 2. Порты и файерволл

Для работы нужны:

- `22/tcp` для SSH
- `80/tcp` для получения и продления сертификатов Let's Encrypt
- `443/tcp` для NaiveProxy
- `443/udp` желательно открыть тоже, если хочешь оставить HTTP/3

Пример для `ufw`:

```sh
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp

ufw enable
ufw status
```

### 3. BBR

Это не обязательно для запуска контейнера, но часто включают для сетевой оптимизации на VPS:

```sh
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_congestion_control
```

Ожидаемое значение:

```text
net.ipv4.tcp_congestion_control = bbr
```

### 4. Docker

На сервере должны быть установлены:

- Docker Engine
- Docker Compose plugin

Проверка:

```sh
docker --version
docker compose version
```

## Настройка

### 1. Заполни `.env`

Открой `.env` и подставь свои значения:

```env
DOMAIN=your.domain.com
EMAIL=your@email.com
PROXY_LOGIN=change_me
PROXY_PASSWORD=change_me
```

Важно:

- `DOMAIN` должен уже смотреть на сервер
- `EMAIL` используется для TLS-сертификатов Let's Encrypt
- `PROXY_LOGIN` и `PROXY_PASSWORD` это логин и пароль клиента

### 2. Сгенерируй логин и пароль

```sh
echo "Логин:  $(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 16)"
echo "Пароль: $(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 24)"
```

После этого вставь значения в `.env`.

## Запуск

Сборка и старт:

```sh
docker compose -f Docker-compose.yaml up -d --build
```

Проверить статус:

```sh
docker compose -f Docker-compose.yaml ps
```

Посмотреть логи:

```sh
docker compose -f Docker-compose.yaml logs -f naiveproxy
```



## Как это работает

В [config/Caddyfile](/home/vlad/docker_repo/naiveproxy/config/Caddyfile) используются переменные окружения `Caddy`:

```caddy
:443, {$DOMAIN} {
  tls {$EMAIL}

  forward_proxy {
    basic_auth {$PROXY_LOGIN} {$PROXY_PASSWORD}
    hide_ip
    hide_via
    probe_resistance
  }

  file_server {
    root /var/www/html
  }
}
```

Подстановка значений идет из `.env` через `docker compose`.

## Проверка после запуска

### 1. Проверка синтаксиса итогового compose

```sh
docker compose -f Docker-compose.yaml config
```

### 2. Проверка конфига Caddy внутри контейнера

```sh
docker compose -f Docker-compose.yaml exec naiveproxy caddy validate --config /etc/caddy/Caddyfile
```

### 3. Проверка сертификата и старта

В логах ищи сообщения в духе:

```text
certificate obtained successfully
```

### 4. Проверка доступности сайта

Открой в браузере:

```text
https://your.domain.com
```

Должна открыться страница-заглушка из `site/index.html`.

### 5. Проверка портов на хосте

```sh
ss -tlnup | grep 443
```

### 6. Проверка работы прокси

Для проверки прокси можно выполнить запросём через `curl`:

```bash
curl -x https://YOUR_LOGIN:YOUR_PASSWORD@your.domain.com:443 https://ipinfo.io
```

## Строка для клиента

Шаблон:

```text
naive+https://YOUR_LOGIN:YOUR_PASSWORD@your.domain.com:443
```

Пример с подстановкой своих данных:

```text
naive+https://mylogin:mypassword@your.domain.com:443
```

Такую ссылку можно импортировать в клиент.

## Клиенты

- iOS: Karing
- Android: NekoBox
- Android: Karing
- Windows: Hiddify
- Windows: NekoRay
- Windows: V2RayN

Для `NekoBox` может понадобиться naive-плагин, если используемая сборка не содержит его из коробки.

## Полезные команды

Запуск:

```sh
docker compose -f Docker-compose.yaml up -d
```

Пересборка после изменений `Dockerfile`:

```sh
docker compose -f Docker-compose.yaml up -d --build
```

Перезапуск контейнера:

```sh
docker compose -f Docker-compose.yaml restart naiveproxy
```

Остановка:

```sh
docker compose -f Docker-compose.yaml down
```

Логи в реальном времени:

```sh
docker compose -f Docker-compose.yaml logs -f naiveproxy
```

Мягкая перезагрузка Caddy без остановки контейнера:

```sh
docker compose -f Docker-compose.yaml exec naiveproxy caddy reload --config /etc/caddy/Caddyfile
```

Проверка версии `caddy` внутри контейнера:

```sh
docker compose -f Docker-compose.yaml exec naiveproxy caddy version
```

## Добавление второго пользователя

Если нужен второй пользователь, удобнее добавить его вручную в [config/Caddyfile](/home/vlad/docker_repo/naiveproxy/config/Caddyfile), а не через `.env`.

Пример:

```caddy
forward_proxy {
  basic_auth LOGIN_1 PASSWORD_1
  basic_auth LOGIN_2 PASSWORD_2
  hide_ip
  hide_via
  probe_resistance
}
```

После изменения примени конфиг:

```sh
docker compose -f Docker-compose.yaml exec naiveproxy caddy reload --config /etc/caddy/Caddyfile
```

Если reload не сработал, можно просто перезапустить контейнер:

```sh
docker compose -f Docker-compose.yaml restart naiveproxy
```

## Примечания

- Сертификаты и служебные данные `Caddy` сохраняются в volume `caddy_data` и `caddy_config`
- `network_mode: host` здесь не нужен, достаточно обычного bridge и проброса портов
- Если сервер стоит за NAT, нужно пробросить `80` и `443` на внешний IP
- Если сертификат не выпускается, в первую очередь проверь DNS, доступность `80/tcp` снаружи и логи контейнера
