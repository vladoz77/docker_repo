# Traefik Reverse Proxy with Docker Compose

Проект настройки обратного прокси Traefik с использованием Docker Compose и самоподписанных SSL-сертификатов.

## Структура проекта

```
├── certs/                 # Директория с SSL-сертификатами
│   ├── local.crt
│   └── local.key
├── config/                # Конфигурационные файлы
│   └── tls.yaml
├── docker-compose.yaml    # Docker Compose конфигурация
└── Readme.md             # Документация
```

## Предварительные требования

- Docker
- Docker Compose
- OpenSSL (для генерации сертификатов)

## Генерация самоподписанных сертификатов

```bash
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/local.key -out certs/local.crt \
  -subj "/CN=*.home.local"
```

## Запуск проекта

1. Клонируйте или создайте структуру проекта
2. Сгенерируйте SSL-сертификаты (см. выше)
3. Запустите контейнеры:

```bash
docker-compose up -d
```

## Конфигурация

### Traefik сервис

- **Порты:**
  - 80 (HTTP)
  - 443 (HTTPS)
  - 8082 (Metrics)

- **Точки входа:**
  - `web` (HTTP, порт 80)
  - `websecure` (HTTPS, порт 443)
  - `metrics` (Prometheus метрики, порт 8082)

### Сети

Создается сеть `proxy` для коммуникации между контейнерами.

### Панель управления

Панель управления Traefik доступна по адресу:
```
https://traefik.home.local
```

## Конфигурационные файлы

### docker-compose.yaml

Основной файл конфигурации Docker Compose с настройками:
- Проброс портов
- Монтирование томов
- Настройки безопасности
- Docker labels для автоматической конфигурации

### config/tls.yaml

Конфигурация TLS с указанием путей к сертификатам:
```yaml
tls:
  certificates:
    - certFile: /certs/local.crt
      keyFile:  /certs/local.key
```

## Использование

### Добавление новых сервисов

Для добавления нового сервиса в прокси, добавьте следующие labels в docker-compose.yaml:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.сервис.rule=Host(`сервис.home.local`)"
  - "traefik.http.routers.сервис.entrypoints=websecure"
  - "traefik.http.routers.сервис.tls=true"
```

### Мониторинг

Метрики Prometheus доступны на порту 8082.

## Безопасность

- Используется базовая аутентификация для панели управления
- Самоподписанные сертификаты для локального использования
- Ограниченные привилегии контейнера

## Примечания

- Сертификаты самоподписанные - для продакшн-среды рекомендуется использовать доверенные сертификаты
- Настройте DNS или hosts файл для домена `home.local`
- Для внешнего доступа потребуется настройка портов на роутере и использование реальных доменов

## Команды управления

```bash
# Запуск
docker-compose up -d

# Остановка
docker-compose down

# Просмотр логов
docker-compose logs -f traefik

# Перезагрузка
docker-compose restart traefik
```