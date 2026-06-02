# Docker Registry Proxy

Локальный реестр Docker с прокси к официальному Docker Hub для кеширования и управления Docker образами.

## Описание

Этот проект развертывает Docker Registry v2 с конфигурацией прокси. Реестр позволяет:

- **Кеширование образов** — скачанные образы хранятся локально
- **Прокси к Docker Hub** — автоматическое перенаправление запросов к официальному реестру
- **Аутентификация** — подключение к Docker Hub с вашими учетными данными
- **Локальная сеть** — изолированная Docker сеть для работы контейнеров

## Требования

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Структура проекта

```
.
├── docker-compose.yaml    # Конфигурация Docker Compose
├── config/
│   └── config.yml         # Конфигурация Docker Registry
├── .env                   # Переменные окружения (не коммитить!)
└── .gitignore             # Игнорирование файлов
```

## Установка и запуск

### 1. Настройка переменных окружения

Создайте файл `.env` в корневой папке проекта или обновите существующий с вашими учетными данными Docker Hub:

```bash
DOCKER_USER=your_username
DOCKER_PASSWORD=your_docker_pat_or_password
```

**⚠️ Важно:** Используйте Personal Access Token (PAT) вместо пароля для лучшей безопасности.

[Как получить Personal Access Token](https://docs.docker.com/docker-hub/access-tokens/)

### 2. Запуск реестра

```bash
docker-compose up -d
```

Реестр будет доступен по адресу: **`http://localhost:5000`**

### 3. Проверка статуса

```bash
# Проверить, что контейнер запущен
docker ps | grep local-registry

# Проверить здоровье реестра
curl http://localhost:5000/v2/
```

Успешный ответ:
```json
{}
```

## Использование

### Назначить тег образа для локального реестра

```bash
docker tag my-image:latest localhost:5000/my-image:latest
```

### Загрузить образ в реестр

```bash
docker push localhost:5000/my-image:latest
```

### Скачать образ из реестра

```bash
docker pull localhost:5000/my-image:latest
```

### Использование с docker-compose

В других `docker-compose.yaml` файлах указывайте образ с префиксом реестра:

```yaml
services:
  app:
    image: localhost:5000/my-image:latest
    networks:
      - local-registry
    # ...

networks:
  local-registry:
    name: local-registry
    external: true
```

## Конфигурация

### Файл конфигурации: `config/config.yml`

| Параметр | Описание |
|----------|---------|
| `log.level` | Уровень логирования (`debug`, `info`, `warning`, `error`) |
| `http.addr` | Адрес и порт слушания (`:5000`) |
| `proxy.remoteurl` | URL официального Docker Registry |
| `storage.filesystem.rootdirectory` | Путь к хранилищу образов |

### Переменные окружения

| Переменная | Описание |
|-----------|---------|
| `DOCKER_USER` | Имя пользователя Docker Hub |
| `DOCKER_PASSWORD` | Пароль или Personal Access Token |

## Команды

### Остановить реестр

```bash
docker-compose down
```

### Остановить и удалить данные

```bash
docker-compose down -v
```

### Просмотр логов

```bash
docker-compose logs -f registry
```

### Список загруженных образов

```bash
curl http://localhost:5000/v2/_catalog
```

Ответ:
```json
{
  "repositories": [
    "my-image",
    "another-image"
  ]
}
```

### Список тегов образа

```bash
curl http://localhost:5000/v2/{image_name}/tags/list
```

Пример:
```bash
curl http://localhost:5000/v2/my-image/tags/list
```

Ответ:
```json
{
  "name": "my-image",
  "tags": [
    "latest",
    "v1.0"
  ]
}
```

## Томы и данные

- **`registry_data`** — томе с данными образов, сохраняется на хосте

Данные реестра сохраняются даже при остановке контейнера. Для полного удаления используйте:

```bash
docker-compose down -v
```

## Сеть

Реестр работает в изолированной Docker сети `local-registry` с драйвером `bridge`. Это позволяет другим контейнерам обращаться к реестру по имени хоста `registry` или по адресу сети.

## Безопасность

⚠️ **Важные замечания:**

1. **Не коммитьте `.env` файл** — он содержит учетные данные
2. Используйте **Personal Access Token** вместо пароля
3. Реестр доступен локально по HTTP — используйте HTTPS для продакшена
4. Для продакшена рассмотрите использование аутентификации и SSL/TLS

## Решение проблем

### Реестр не доступен

```bash
# Проверьте, запущен ли контейнер
docker ps | grep local-registry

# Если контейнер остановлен, перезапустите
docker-compose restart registry
```

### Ошибка аутентификации

1. Проверьте учетные данные в `.env`
2. Убедитесь, что Personal Access Token имеет права на репозитории
3. Перезапустите контейнер: `docker-compose restart registry`

### Ошибка при загрузке образа

```bash
# Убедитесь, что Docker использует незащищенный реестр (только для локальной разработки)
# В /etc/docker/daemon.json добавьте:
{
  "insecure-registries": ["localhost:5000"]
}

# Перезагрузите Docker
sudo systemctl restart docker
```

### Проверить логи реестра

```bash
docker-compose logs registry
```

## Ссылки

- [Docker Registry Documentation](https://docs.docker.com/registry/)
- [Docker Registry Configuration](https://docs.docker.com/registry/configuration/)
- [Docker Hub API](https://docs.docker.com/docker-hub/api/latest/)
