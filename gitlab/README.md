# GitLab + Traefik Docker Setup

Полнофункциональная настройка **GitLab Community/Enterprise Edition** с **Traefik** reverse proxy для автоматического управления SSL сертификатами через Let's Encrypt.

## 📋 Требования

- Docker (19.03+)
- Docker Compose (1.29+)
- Свободные порты: 80, 443, 22
- Доменное имя с DNS записями

## 🚀 Быстрый старт

### 1. Клонирование и подготовка

```bash
cd docker_repo/gitlab
```

### 2. Настройка переменных окружения

Скопируй `.env.example` в `.env` и отредактируй:

```bash
cp .env.example .env
nano .env
```

**Важные параметры:**
- `GITLAB_HOSTNAME` - ваш домен (например, `gitlab.example.com`)
- `GITLAB_ROOT_PASSWORD` - пароль администратора GitLab
- `TRAEFIK_ACME_EMAIL` - email для Let's Encrypt уведомлений
- `GITLAB_VERSION` - версия GitLab (по умолчанию latest)
- `TRAEFIK_VERSION` - версия Traefik (по умолчанию latest)

### 3. Запуск контейнеров

```bash
docker-compose up -d
```

Проверка статуса:
```bash
docker-compose ps
```

### 4. Доступ к GitLab

- **Web**: https://your-gitlab-hostname
- **SSH**: `git clone git@your-gitlab-hostname:group/project.git`
- **Root пароль**: из переменной `GITLAB_ROOT_PASSWORD`

## 📁 Структура проекта

```
.
├── docker-compose.yaml          # Основная конфигурация
├── .env                         # Переменные окружения (в .gitignore)
├── .env.example                 # Пример переменных (для репозитория)
├── .gitignore                   # Исключённые файлы
├── gitlab/
│   ├── gitlab.rb.template       # Шаблон конфига GitLab
│   └── logs/                    # Логи GitLab (игнорируется)
├── traefik/
│   ├── traefik.yml.template     # Шаблон конфига Traefik
│   └── acme.json                # Хранилище SSL сертификатов (игнорируется)
└── README.md                    # Этот файл
```

## ⚙️ Конфигурация

### Сервисы

#### gitlab-init
Инициализационный контейнер, который:
- Генерирует `gitlab.rb` из шаблона с переменными окружения
- Генерирует `traefik.yml` из шаблона с переменными окружения
- Подготавливает конфигурационные директории

#### gitlab
GitLab Community/Enterprise Edition с поддержкой:
- HTTP/HTTPS через Traefik
- SSH на порту 22
- Автоматические SSL сертификаты

#### traefik
Reverse proxy с функциями:
- Автоматическое перенаправление HTTP → HTTPS
- Let's Encrypt интеграция
- Docker labels для маршрутизации
- Prometheus метрики на порту 8082

### Переменные окружения

Все параметры настраиваются через `.env`:

```env
# GitLab версия
GITLAB_VERSION=19.0.2-ce.0

# Доменное имя для GitLab
GITLAB_HOSTNAME=gitlab.example.com

# Пароль администратора
GITLAB_ROOT_PASSWORD=SecurePassword123!

# Версия Traefik
TRAEFIK_VERSION=latest

# Email для Let's Encrypt
TRAEFIK_ACME_EMAIL=admin@example.com
```

## 🔐 SSL/HTTPS

Все SSL сертификаты управляются автоматически:
- Traefik получает сертификат при первом запросе
- Сертификаты хранятся в `traefik/acme.json`
- Автоматическое обновление за 30 дней до истечения
- Email уведомления на `TRAEFIK_ACME_EMAIL`

**⚠️ Важно**: Убедитесь, что DNS уже настроен перед запуском!

## 🔌 SSH Настройка

GitLab SSH доступен по порту 22. Для клонирования репозиториев:

```bash
git clone git@gitlab.example.com:group/project.git
```

SSH пара должна быть добавлена в GitLab профиль.

## 📊 Мониторинг

### Prometheus метрики

Traefik предоставляет метрики на:
```
http://localhost:8082/metrics
```

Для интеграции с Prometheus добавьте в `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'traefik'
    static_configs:
      - targets: ['localhost:8082']
```

## 🔧 Управление

### Просмотр логов

```bash
# Все логи
docker-compose logs -f

# Только GitLab
docker-compose logs -f gitlab

# Только Traefik
docker-compose logs -f traefik
```

### Перезагрузка

```bash
# Перезагрузить все контейнеры
docker-compose restart

# Остановить
docker-compose down

# Запустить заново с очисткой
docker-compose down -v
docker-compose up -d
```

### Обновление версий

Отредактируй `.env`:
```env
GITLAB_VERSION=19.1.0-ce.0
TRAEFIK_VERSION=3.0
```

Затем перезагрузи контейнеры:
```bash
docker-compose up -d
```

## 🐛 Troubleshooting

### GitLab не отвечает

1. Проверь статус контейнера:
   ```bash
   docker-compose ps
   ```

2. Смотри логи:
   ```bash
   docker-compose logs gitlab
   ```

3. Убедись, что `gitlab-init` выполнен успешно:
   ```bash
   docker-compose logs gitlab-init
   ```

### SSL сертификат не выдан

1. Проверь DNS:
   ```bash
   nslookup gitlab.example.com
   ```

2. Убедись, что порты 80 и 443 доступны:
   ```bash
   netstat -tlnp | grep -E ':(80|443)'
   ```

3. Смотри логи Traefik:
   ```bash
   docker-compose logs traefik
   ```

### Медленное соединение SSH

SSH тоннелируется через контейнер. Может потребоваться:
- Увеличить `shm_size` для GitLab (сейчас 256m)
- Проверить пропускную способность сети

### acme.json не инициализирован

При первом запуске:
```bash
# Traefik создаст файл автоматически
# Если нужно вручную:
touch traefik/acme.json
chmod 600 traefik/acme.json
docker-compose up -d
```

## 📚 Дополнительные ресурсы

- [GitLab Documentation](https://docs.gitlab.com/ee/install/docker.html)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Let's Encrypt](https://letsencrypt.org/)

## 📝 Безопасность

- **Никогда** не коммитьте `.env` файл
- Используйте сильные пароли для `GITLAB_ROOT_PASSWORD`
- Регулярно обновляйте версии `GITLAB_VERSION` и `TRAEFIK_VERSION`
- Следите за обновлениями безопасности
- Используйте только HTTPS для доступа к GitLab

