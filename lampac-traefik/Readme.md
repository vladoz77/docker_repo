# 🌐 Lampac + Traefik (HTTPS + Let's Encrypt)

Простой и безопасный способ запустить [Lampac](https://github.com/immisterio/Lampac) за reverse-proxy **Traefik** с автоматическим получением **SSL-сертификатов от Let's Encrypt** и принудительным редиректом на `HTTPS`.

---

## 📁 Структура проекта

```
.
├── docker-compose.yaml    # Основной конфиг Docker
├── init.conf              # Конфигурация Lampac
├── manifest.json          # Список активных плагинов
└── letsencrypt/           # Автосоздаётся, хранит сертификаты (не в Git!)
```

---

## 🚀 Быстрый старт

### 1. Установи Docker и Docker Compose

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install docker.io docker-compose -y
```

### 2. Создай проект

```bash
mkdir lampac-traefik && cd lampac-traefik
```

Создай файлы:
- `docker-compose.yaml`
- `init.conf`
- `manifest.json`

(или скопируй из этого репозитория)

### 3. Создай папку для сертификатов

```bash
mkdir -p ./letsencrypt
touch ./letsencrypt/acme.json
chmod 600 ./letsencrypt/acme.json  # 🔐 Обязательно!
```

### 4. Запусти

```bash
docker-compose up -d
```

---

## 🌍 Доступные сервисы

| Сервис | Адрес |
|------|-------|
| **Lampac** | [https://lampa.kz.home-local.site](https://lampa.kz.home-local.site) |
| **Traefik Dashboard** | [https://dashboard.kz.home-local.site](https://dashboard.kz.home-local.site) |

> 🔒 HTTPS включён автоматически через Let's Encrypt

---

## ⚙️ Настройка DNS / hosts

Так как домены `.home-local.site` — публичные, но ты можешь использовать их локально.

### Вариант 1: Локальный hosts (для теста)

Открой файл:
```bash
sudo nano /etc/hosts
```

Добавь:
```
127.0.0.1 lampa.kz.home-local.site
127.0.0.1 dashboard.kz.home-local.site
```

> ⚠️ Let's Encrypt **не выдаст сертификат**, если домен не разрешается публично.  
> Эти домены работают **только если они публичные и A-записи ведут на твой IP**.

### Вариант 2: Используй публичный домен

Если у тебя есть домен (например, `yourdomain.site`), замени:
```yaml
Host(`lampa.yourdomain.site`)
```
и настрой A-записи.

---

## 🔐 Let's Encrypt (авто-SSL)

- Сертификаты автоматически обновляются
- Хранятся в `./letsencrypt/acme.json`
- Используется **HTTP-01 challenge**
- Email для уведомлений: `vladoz77@yandex.ru` (указан в конфиге)

> ✅ Редирект с `HTTP → HTTPS` включён по умолчанию

---

## 🧩 Плагины Lampac

Активные плагины указаны в `manifest.json`:

| Плагин | Описание |
|-------|--------|
| `SISI.dll` | Поиск по трекерам |
| `Online.dll` | Онлайн-кинотеатры |
| `DLNA.dll` | DLNA-трансляция |
| `JacRed.dll` | Интеграция с Jackett |
| `TorrServer.dll` | ❌ Отключён |

> ✅ Все плагины должны работать по HTTPS, если заголовки настроены корректно

---

## 🛠 Конфигурация Lampac (`init.conf`)

| Параметр | Значение |
|--------|--------|
| `listenport` | `9118` |
| `listenhost` | `lampa.kz.home-local.site` |
| `listenscheme` | `https` ← **важно для генерации ссылок** |
| `firefox.enable` | `true` | (для парсинга)
| `LampaWeb.initPlugins` | Включены: online, sisi, sync, backup |

> ⚠️ `listenscheme: "https"` — помогает Lampac генерировать правильные URL

---

## 🔧 Как обновить

```bash
docker-compose pull
docker-compose down
docker-compose up -d --force-recreate
```

---

## 📦 Требования

- Docker 20.10+
- Docker Compose 2.0+
- Доступ в интернет
- Порт `80` и `443` свободны
- Домен с публичным DNS (для Let's Encrypt)

---

## ❓ Проблемы и решения

### 🔴 Mixed Content: `http://` вместо `https://`

**Причина**: Lampac не видит, что запрос идёт по HTTPS.

**Решение**:
1. Убедись, что `listenscheme: "https"` в `init.conf`
2. Проверь, что Traefik передаёт заголовки:
   - `X-Forwarded-Proto: https`
   - `X-Scheme: https`
3. Добавь в `docker-compose.yaml`:
   ```yaml
   - "--serversTransport.forwardedHeaders.insecure=true"
   ```

### 🔴 Сертификат не выдаётся

**Причина**: домен не публичный или порт 80 заблокирован.

**Решение**:
- Убедись, что `lampa.kz.home-local.site` → публичный IP
- Проверь, что порт 80 **открыт на роутере и фаерволе**
- Или используй `nip.io` / `sslip.io` для теста

---


> ✅ Готово! Теперь у тебя работает **безопасный, автоматизированный доступ к Lampac через HTTPS** с красивыми URL и нулевым обслуживанием сертификатов.

