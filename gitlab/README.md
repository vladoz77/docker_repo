# GitLab CE + Traefik + Postfix + PostgreSQL + Redis

Этот репозиторий содержит Docker Compose-стек для запуска GitLab Community Edition за Traefik с HTTPS, отдельным SMTP relay на Postfix и внешними сервисами PostgreSQL и Redis.

## Что входит в стек

- GitLab CE в контейнере `gitlab`
- Traefik в контейнере `traefik` с HTTP/HTTPS и TCP SSH proxy
- Postfix в контейнере `postfix` для исходящей почты GitLab с DKIM
- PostgreSQL в контейнере `postgres`
- Redis в контейнере `redis`

GitLab доступен по HTTPS через Traefik, SSH GitLab публикуется на порту из переменной `SSH_PORT`, а Postfix работает только внутри docker-сети.

## Требования

- Docker Engine с Docker Compose plugin
- Утилита `envsubst`
- DNS-записи для домена GitLab и почтового hostname
- Открытые входящие порты `80`, `443` и `SSH_PORT`
- Открытый исходящий TCP/25 для доставки почты
- Для скрипта регистрации раннера: `curl`, `jq`, пакет `gitlab-runner` и действительный GitLab PAT

## Структура проекта

- [docker-compose.yaml](https://github.com/vladoz77/docker_repo/blob/master/gitlab/docker-compose.yaml) — описание сервисов и сетей
- [gitlab-deploy.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-deploy.sh) — генерация конфигов и запуск стека
- [gitlab-backup.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-backup.sh) — создание резервной копии GitLab и выгрузка в Restic
- [gitlab-restore.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-restore.sh) — восстановление из Restic и запуск `gitlab-backup restore`
- [gitlab-runner.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-runner.sh) — создание инстанс-раннера в GitLab, установка `gitlab-runner` и регистрация
- [templates/gitlab.rb.template](https://github.com/vladoz77/docker_repo/blob/master/gitlab/templates/gitlab.rb.template) — шаблон конфигурации GitLab
- [templates/traefik.yml.template](https://github.com/vladoz77/docker_repo/blob/master/gitlab/templates/traefik.yml.template) — шаблон конфигурации Traefik

## Быстрый старт

1. Скопируйте пример окружения:

```bash
cp .env.example .env
```

2. Отредактируйте `.env` под ваш сервер и домены.

3. Сделайте скрипты исполняемыми:

```bash
chmod +x gitlab-deploy.sh gitlab-backup.sh gitlab-restore.sh gitlab-runner.sh
```

4. Запустите деплой:

```bash
./gitlab-deploy.sh
```

Скрипт выполняет следующие действия:

- генерирует [templates/traefik.yml.template](https://github.com/vladoz77/docker_repo/blob/master/gitlab/templates/traefik.yml.template) → `traefik/traefik.yml`
- генерирует [templates/gitlab.rb.template](https://github.com/vladoz77/docker_repo/blob/master/gitlab/templates/gitlab.rb.template) → `gitlab/config/gitlab.rb`
- создаёт `traefik/acme.json` с правами `600`
- запускает `docker compose pull && docker compose up -d`

## Переменные окружения

### GitLab

- `GITLAB_VERSION` — версия образа `gitlab/gitlab-ce`
- `GITLAB_HOSTNAME` — публичный hostname GitLab
- `GITLAB_ROOT_PASSWORD` — пароль root пользователя GitLab
- `SSH_PORT` — внешний SSH-порт GitLab

### Traefik

- `TRAEFIK_VERSION` — версия образа Traefik
- `TRAEFIK_ACME_EMAIL` — email для Let's Encrypt

### SMTP / Postfix

- `SMTP_HOST` — SMTP-хост внутри docker-сети, обычно `postfix`
- `SMTP_PORT` — SMTP-порт внутри docker-сети, обычно `587`
- `SMTP_DOMAIN` — домен отправки почты
- `SMTP_EMAIL_FROM` — адрес отправителя
- `SMTP_DISPLAY_NAME` — отображаемое имя отправителя
- `POSTFIX_HOSTNAME` — hostname Postfix/почтового сервера
- `POSTFIX_ALLOWED_SENDER_DOMAINS` — разрешённые домены отправки
- `POSTFIX_DKIM_SELECTOR` — selector DKIM
- `POSTFIX_NETWORKS` — сети, которым разрешено отправлять почту через Postfix

### PostgreSQL

- `POSTGRES_VERSION` — версия образа PostgreSQL
- `POSTGRES_HOST` — hostname сервера PostgreSQL внутри сети
- `DB_USERNAME` — пользователь базы
- `DB_PASSWORD` — пароль базы
- `DB_PORT` — порт PostgreSQL
- `DB_NAME` — имя базы GitLab

### Redis

- `REDIS_VERSION` - версия образа Redis.
- `REDIS_HOST` - hostname Redis внутри docker-сети, обычно `redis`.
- `REDIS_PORT` - порт Redis внутри docker-сети, обычно `6379`.

## Схема почты

GitLab отправляет письма на `postfix:587` внутри docker-сети:

```ruby
gitlab_rails['smtp_address'] = "postfix"
gitlab_rails['smtp_port'] = 587
gitlab_rails['smtp_tls'] = false
gitlab_rails['smtp_enable_starttls_auto'] = false
```

TLS между GitLab и Postfix не включен, потому что этот трафик идет внутри приватной docker-сети и SMTP-порт Postfix не опубликован наружу.

Postfix дальше доставляет письма внешним почтовым серверам. Для этого у VPS должен быть открыт исходящий порт `25`.

## DNS для почты

Для нормальной доставки писем нужно настроить DNS для домена отправки. Ниже примеры для домена `devhomelab.site`, почтового hostname `mail.devhomelab.site` и IP `92.53.124.199`.

### A запись

Почтовый hostname должен указывать на IP сервера:

| Поле | Значение |
| --- | --- |
| Имя | `mail` |
| Тип | `A` |
| Значение | `92.53.124.199` |
| TTL | `600` |

Для своего проекта подставьте IP вашего VPS. Полное имя записи получится `mail.example.com`.

### MX запись

MX указывает, какой сервер принимает почту для домена. Даже если проект в основном отправляет письма, MX полезен для репутации домена и корректной почтовой конфигурации.

| Поле | Значение |
| --- | --- |
| Имя | `@` или `devhomelab.site.` |
| Тип | `MX` |
| Значение | `10 mail.devhomelab.site` |
| TTL | `600` |

`10` - приоритет MX. Чем меньше число, тем выше приоритет.

### SPF запись

SPF разрешает указанному серверу отправлять почту от имени домена:

| Поле | Значение |
| --- | --- |
| Имя | `@` или `devhomelab.site.` |
| Тип | `TXT` |
| Значение | `"v=spf1 a mx ip4:92.53.124.199 -all"` |
| TTL | `600` |

Для своего сервера замените IP. Если хотите разрешить отправку только с `mail.example.com`, можно использовать более строгий вариант:

```text
"v=spf1 a:mail.example.com mx -all"
```

`-all` означает жесткий запрет отправки со всех остальных источников.

### DKIM запись

DKIM подтверждает, что письмо подписано вашим Postfix. Ключи создаются в директории `postfix/dkim` после первого запуска контейнера.

После запуска найдите `.txt` файл:

```bash
ls postfix/dkim
```

Если selector равен `mail`, имя DNS-записи:

| Поле | Значение |
| --- | --- |
| Имя | `mail._domainkey` |
| Тип | `TXT` |
| Значение | содержимое DKIM из `.txt` файла |
| TTL | `600` |

В DNS значение должно быть одной строкой без скобок и переносов, например:

```text
"v=DKIM1; h=sha256; k=rsa; s=email; p=PUBLIC_KEY"
```

Если в файле ключ разбит на несколько строк в кавычках, соедините части `p=` в одну длинную строку.

### DMARC запись

DMARC задает политику обработки писем, которые не прошли SPF/DKIM. Для мягкого старта можно использовать quarantine:

| Поле | Значение |
| --- | --- |
| Имя | `_dmarc` |
| Тип | `TXT` |
| Значение | `"v=DMARC1; p=quarantine; rua=mailto:postmaster@devhomelab.site"` |
| TTL | `600` |

Для своего домена замените email в `rua`. Более мягкий вариант для первых тестов:

```text
"v=DMARC1; p=none; rua=mailto:postmaster@example.com"
```

После проверки доставки можно перейти на `p=quarantine`, а затем на `p=reject`.

### PTR/rDNS

У хостера VPS нужно настроить reverse DNS для IP сервера:

```text
92.53.124.199 -> mail.devhomelab.site
```

PTR/rDNS обычно настраивается не в DNS-панели домена, а в панели хостера или через обращение в поддержку.

### Проверка через dig

После добавления DNS-записей проверьте, что они резолвятся. Примеры для `devhomelab.site`:

```bash
dig +short A mail.devhomelab.site
dig +short MX devhomelab.site
dig +short TXT devhomelab.site
dig +short TXT mail._domainkey.devhomelab.site
dig +short TXT _dmarc.devhomelab.site
dig +short -x 92.53.124.199
```

Ожидаемо:

```text
dig +short A mail.devhomelab.site
92.53.124.199

dig +short MX devhomelab.site
10 mail.devhomelab.site.

dig +short TXT devhomelab.site
"v=spf1 a mx ip4:92.53.124.199 -all"

dig +short TXT mail._domainkey.devhomelab.site
"v=DKIM1; h=sha256; k=rsa; s=email; p=..."

dig +short TXT _dmarc.devhomelab.site
"v=DMARC1; p=quarantine; rua=mailto:postmaster@devhomelab.site"

dig +short -x 92.53.124.199
mail.devhomelab.site.
```

Если DNS недавно изменен, ответы могут появиться не сразу. При TTL `600` обычно стоит подождать 10-15 минут и повторить проверку.

## Проверка после деплоя

Проверка конфигурации:

```bash
docker compose config
```

Просмотр логов:

```bash
docker compose logs -f traefik
docker compose logs -f gitlab
docker compose logs -f postfix
```

Проверка статуса контейнеров:

```bash
docker compose ps
```

Проверка готовности GitLab:

```bash
docker compose exec gitlab gitlab-ctl status
```

Проверка доступности сайта:

```bash
curl -I https://your-gitlab-hostname
```

Проверка доступа к SMTP внутри сети:

```bash
docker compose exec gitlab bash -lc 'timeout 5 bash -c "</dev/tcp/postfix/587" && echo "postfix:587 is reachable"'
```

Проверка права `acme.json`:

```bash
stat -c '%a %n' traefik/acme.json
```

Ожидаемый режим:

```text
600 traefik/acme.json
```

## Бэкапы

Скрипт [gitlab-backup.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-backup.sh) выполняет резервное копирование следующим образом:

- создаёт штатную резервную копию GitLab через `gitlab-backup create`
- архивирует конфигурацию GitLab и каталог бэкапов
- отправляет данные в Restic в удалённое хранилище

Для работы скрипта должны быть заданы переменные окружения:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `RESTIC_PASSWORD`
- `RESTIC_REPOSITORY`

Запуск:

```bash
./gitlab-backup.sh
```

Скрипт хранит резервные копии в Restic с ротацией:

- ежедневно — 7 снимков
- еженедельно — 4 снимка
- ежемесячно — 12 снимков

## Восстановление

Скрипт [gitlab-restore.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-restore.sh) выполняет восстановление из Restic:

1. восстанавливает данные в временную директорию
2. копирует конфигурацию GitLab в `./gitlab/config`
3. копирует архивы бэкапов в `./gitlab/backups`
4. останавливает GitLab процессы
5. запускает `gitlab-backup restore`
6. выполняет `gitlab-ctl reconfigure` и `gitlab-ctl restart`

Запуск:

```bash
./gitlab-restore.sh
```

Перед восстановлением убедитесь, что у вас есть актуальные бэкапы и конфиг `gitlab-secrets.json`.

## Регистрация GitLab Runner

Скрипт [gitlab-runner.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-runner.sh) выполняет полный цикл для создания раннера:

1. создаёт инстанс-раннер в GitLab через API
2. устанавливает `gitlab-runner` на хосте
3. регистрирует раннер с executor `shell`

Перед запуском нужно отредактировать скрипт и задать:

- `GITLAB_URL`
- `PAT_TOKEN`
- `RUNNER_TAGS` при необходимости

Запуск:

```bash
sudo ./gitlab-runner.sh
```

> Скрипт должен запускаться от root, потому что устанавливает пакет и регистрирует сервис `gitlab-runner`.

## Права доступа

Скрипты не требуют запуска от root, кроме [gitlab-runner.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-runner.sh). Для нормальной работы пользователю нужно:

- иметь доступ к Docker socket
- иметь права записи в каталог проекта
- иметь право менять режим `traefik/acme.json`

Обычно это root через `sudo ./deploy.sh` / `sudo ./backup.sh` или отдельный пользователь в группе `docker`, владеющий директорией проекта.

## Важные файлы

- [docker-compose.yaml](https://github.com/vladoz77/docker_repo/blob/master/gitlab/docker-compose.yaml) — описание сервисов и сетей.
- [.env.example](https://github.com/vladoz77/docker_repo/blob/master/gitlab/.env.example) — пример переменных окружения.
- [gitlab-deploy.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-deploy.sh) — генерация конфигов и запуск compose.
- [gitlab-backup.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-backup.sh) — создание резервных копий GitLab и выгрузка в Restic.
- [gitlab-restore.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-restore.sh) — восстановление данных из Restic.
- [gitlab-runner.sh](https://github.com/vladoz77/docker_repo/blob/master/gitlab/gitlab-runner.sh) — создание и регистрация GitLab Runner.
- [templates/traefik.yml.template](https://github.com/vladoz77/docker_repo/blob/master/gitlab/templates/traefik.yml.template) — шаблон Traefik.
- [templates/gitlab.rb.template](https://github.com/vladoz77/docker_repo/blob/master/gitlab/templates/gitlab.rb.template) — шаблон конфигурации GitLab.
- `traefik/acme.json` — файл с сертификатами Let's Encrypt, создаётся при первом деплое.
- `gitlab/config/gitlab.rb` — сгенерированная конфигурация GitLab, создаётся скриптом деплоя.
- `traefik/traefik.yml` — сгенерированная конфигурация Traefik, создаётся скриптом деплоя.
- `gitlab/backups` — каталог для штатных GitLab backup-архивов.
- `postfix/dkim` — каталог с DKIM-ключами Postfix, создаётся после первого запуска контейнера.
