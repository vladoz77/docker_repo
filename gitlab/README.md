# GitLab + Traefik + Postfix Relay

Docker Compose проект для запуска GitLab CE за Traefik с Let's Encrypt и отдельным Postfix relay для исходящей почты GitLab.

## Состав

- `gitlab` - GitLab CE.
- `traefik` - reverse proxy для HTTPS и TCP proxy для SSH.
- `postfix` - send-only SMTP relay для писем GitLab с DKIM.

GitLab доступен по HTTPS через Traefik. SSH GitLab публикуется на порту из переменной `SSH_PORT`. Postfix не публикуется наружу и доступен только внутри docker-сети `gitlab_net`.

## Требования

- Docker и Docker Compose plugin.
- Утилита `envsubst`.
- Домен с DNS-доступом.
- Открытые входящие порты `80`, `443` и значение `SSH_PORT`.
- Открытый исходящий порт `25` у хостера для доставки почты на внешние MX.

## Быстрый старт

1. Скопировать пример окружения:

```bash
cp .env.example .env
```

2. Заполнить `.env`.

3. Запустить деплой:

```bash
./deploy.sh
```

Скрипт генерирует:

- `traefik/traefik.yml` из `traefik/traefik.yml.template`
- `gitlab/config/gitlab.rb` из `gitlab/config/gitlab.rb.template`
- `traefik/acme.json` с правами `600`

После этого выполняется `docker compose pull && docker compose up -d`.

## Переменные окружения

### GitLab

- `GITLAB_VERSION` - версия образа `gitlab/gitlab-ce`.
- `GITLAB_HOSTNAME` - публичный hostname GitLab, например `gitlab.example.com`.
- `GITLAB_ROOT_PASSWORD` - начальный пароль root-пользователя GitLab.
- `SSH_PORT` - внешний SSH-порт GitLab, например `2222`.

### Traefik

- `TRAEFIK_VERSION` - версия образа Traefik.
- `TRAEFIK_ACME_EMAIL` - email для Let's Encrypt.

### GitLab SMTP

- `SMTP_DOMAIN` - домен отправки, например `example.com`.
- `SMTP_HOST` - SMTP-хост внутри docker-сети, обычно `postfix`.
- `SMTP_PORT` - SMTP-порт внутри docker-сети, обычно `587`.
- `SMTP_EMAIL_FROM` - адрес отправителя GitLab, например `gitlab@example.com`.
- `SMTP_DISPLAY_NAME` - отображаемое имя отправителя.

### Postfix

- `POSTFIX_HOSTNAME` - hostname почтового сервера, например `mail.example.com`.
- `POSTFIX_ALLOWED_SENDER_DOMAINS` - домены, с которых postfix разрешает отправку.
- `POSTFIX_DKIM_SELECTOR` - DKIM selector, обычно `mail`.
- `POSTFIX_NETWORKS` - сети, которым разрешено отправлять через postfix.

### PostgreSQL

- `POSTGRES_VERSION` - версия образа PostgreSQL.
- `POSTGRES_HOST` - hostname PostgreSQL внутри docker-сети, обычно `postgres`.
- `DB_USERNAME` - пользователь базы GitLab.
- `DB_PASSWORD` - пароль пользователя базы GitLab.
- `DB_PORT` - порт PostgreSQL внутри docker-сети, обычно `5432`.
- `DB_NAME` - имя базы GitLab, обычно `gitlabhq_production`.

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

## Проверка

Проверить итоговый compose:

```bash
docker compose config
```

Посмотреть логи:

```bash
docker compose logs -f traefik
docker compose logs -f gitlab
docker compose logs -f postfix
```

### Готовность GitLab

GitLab после первого запуска может подниматься несколько минут. Проверить состояние контейнеров:

```bash
docker compose ps
```

Проверить health endpoint внутри контейнера:

```bash
docker compose exec gitlab gitlab-ctl status
```

Проверить доступность GitLab через Traefik:

```bash
curl -I https://gitlab.example.com
```

Для своего сервера замените `gitlab.example.com` на значение `GITLAB_HOSTNAME`.

### Проверка Postfix

Проверить, что GitLab видит SMTP-порт Postfix внутри docker-сети:

```bash
docker compose exec gitlab bash -lc 'timeout 5 bash -c "</dev/tcp/postfix/587" && echo "postfix:587 is reachable"'
```

Посмотреть логи Postfix:

```bash
docker compose logs -f postfix
```

### Проверка отправки почты из GitLab

Отправить тестовое письмо одной командой:

```bash
docker compose exec gitlab gitlab-rails runner "Notify.test_email('user@example.com', 'GitLab test email', 'SMTP delivery check').deliver_now"
```

Замените `user@example.com` на реальный внешний адрес. После отправки проверьте логи:

```bash
docker compose logs --tail=200 postfix
docker compose logs --tail=200 gitlab
```

В логах Postfix успешная отправка обычно выглядит как `status=sent`. Ошибки доставки чаще всего связаны с закрытым исходящим портом `25`, неправильным SPF/DKIM/PTR или временной блокировкой на стороне получателя.

Проверить права `acme.json`:

```bash
stat -c '%a %n' traefik/acme.json
```

Ожидаемый режим:

```text
600 traefik/acme.json
```

## Бэкапы

Для резервного копирования используется `backup.sh`. Скрипт запускается на хосте и выполняет команды внутри контейнеров через `docker compose exec`.

Что сохраняется:

- штатный GitLab backup в `./backups/gitlab`;
- архив конфигов GitLab: `gitlab/config/gitlab.rb` и `gitlab/config/gitlab-secrets.json`;
- отдельный PostgreSQL dump в custom format `pg_dump -Fc`;
- архив конфигов Traefik: `traefik/traefik.yml` и `traefik/acme.json`.

Перед первым запуском сделайте скрипт исполняемым:

```bash
chmod +x backup.sh
```

Запуск:

```bash
./backup.sh
```

GitLab backup складывается в директорию, проброшенную в контейнер:

```yaml
- './backups/gitlab:/var/opt/gitlab/backups'
```

PostgreSQL dump создается отдельно:

```bash
docker compose exec -T postgres pg_dump \
  -U "$DB_USERNAME" \
  -d "$DB_NAME" \
  -Fc \
  > "./backups/postgres/gitlab-db-YYYY-MM-DD_HH-MM.dump"
```

Этот dump нужен как дополнительная страховка. Основным способом восстановления GitLab остается штатный GitLab backup вместе с `gitlab-secrets.json`.

### Важные файлы для восстановления

Обязательно сохраняйте:

- `./backups/gitlab/*_gitlab_backup.tar`;
- `./gitlab/config/gitlab-secrets.json`;
- `./gitlab/config/gitlab.rb`;
- `./traefik/acme.json`;
- `.env`.

`gitlab-secrets.json` критичен для восстановления: без него могут не расшифроваться токены, CI variables, runner secrets и другие чувствительные данные GitLab.

`traefik/acme.json` содержит ACME account key и сертификаты Let's Encrypt. При потере Traefik сможет выпустить сертификаты заново, но можно упереться в rate limits Let's Encrypt.

### Ротация

В `backup.sh` используется локальная ротация через `find`:

```bash
BACKUP_RETENTION_DAYS=7
find "$BACKUP_DIR" -type f -mtime +"$BACKUP_RETENTION_DAYS" -exec rm -f {} \;
```

По умолчанию удаляются локальные файлы старше 7 дней. Если нужно хранить бэкапы дольше, измените `BACKUP_RETENTION_DAYS`.

## Права запуска

`deploy.sh` и `backup.sh` не обязаны запускаться от root. Пользователь должен:

- иметь права записи в директорию проекта;
- иметь право менять режим `traefik/acme.json`;
- иметь доступ к Docker socket.

Обычно это root через `sudo ./deploy.sh` / `sudo ./backup.sh` или отдельный пользователь в группе `docker`, владеющий директорией проекта.

## Важные файлы

- `docker-compose.yaml` - сервисы и сети.
- `.env.example` - пример переменных окружения.
- `deploy.sh` - генерация конфигов и запуск compose.
- `backup.sh` - создание локальных бэкапов GitLab, PostgreSQL и Traefik.
- `traefik/traefik.yml.template` - шаблон Traefik.
- `gitlab/config/gitlab.rb.template` - шаблон GitLab Omnibus config.
- `traefik/acme.json` - хранилище сертификатов Let's Encrypt.
- `postfix/dkim` - DKIM-ключи Postfix.
- `backups/gitlab` - штатные GitLab backup archives.
- `backups/postgres` - отдельные PostgreSQL dumps.
