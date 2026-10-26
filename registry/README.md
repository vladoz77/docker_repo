# Docker Registry Proxy Cluster

Локальный набор из трёх экземпляров Docker Registry v2 для работы с Docker Hub, GitHub Container Registry и Quay через прокси. Каждый реестр запускается отдельно, имеет собственный порт, отдельный том данных и собственный конфиг.

## Что входит в проект

В составе проекта три сервиса:

- `docker-registry` — `http://localhost:5000`
- `quay-registry` — `http://localhost:5001`
- `ghcr-registry` — `http://localhost:5002`

Каждый сервис использует собственный конфигурационный файл и отдельный volume:

- `docker_data`
- `quay_data`
- `ghcr_data`

## Требования

- Docker Engine
- Docker Compose v2
- (опционально) HTTP/SOCKS proxy для доступа к внешним реестрам
- права администратора для редактирования настроек Docker daemon

## Структура проекта

```text
.
├── .env.example
├── .env
├── docker-compose.yaml
├── README.md
├── config/
│   ├── docker.yml
│   ├── ghcr.yml
│   └── quay.yml
└── .gitignore
```

## Конфигурация

Основной файл настройки — [docker-compose.yaml](./docker-compose.yaml). В нём описаны три сервиса, каждый из которых:

- поднимает контейнер `registry:3`
- пробрасывает порт `5000`, `5001` или `5002` наружу
- использует отдельный файл конфигурации из `config/*.yml`
- монтирует отдельный volume в `/var/lib/registry`
- передаёт параметры прокси в переменных окружения

### Переменные окружения

В проекте используется файл `.env`:

```dotenv
PROXY_URL=http://proxy.example:8080
NO_PROXY_LIST=localhost,127.0.0.1
```

Если `.env` ещё не создан, скопируйте шаблон:

```bash
cp .env.example .env
```

Параметры:

- `PROXY_URL` — URL HTTP proxy, который будет использоваться контейнерами для исходящих запросов
- `NO_PROXY_LIST` — адреса, которые не должны проходить через proxy (`localhost`, `127.0.0.1` и т.д.)

## Полная настройка Docker daemon

Для работы с локальными реестрами на `localhost:5000`, `localhost:5001`, `localhost:5002` Docker daemon должен быть настроен на доверие к insecure-registry. В противном случае `docker push` и `docker pull` к локальному реестру могут завершаться ошибкой вида `http: server gave HTTP response to HTTPS client` или `Get "http://localhost:5000/v2/": denied`.

### 1. Создайте или отредактируйте файл daemon config

На Linux файл конфигурации Docker daemon обычно находится по пути:

```bash
sudo nano /etc/docker/daemon.json
```

Если файл уже существует, добавьте в него секцию `insecure-registries`.

### 2. Добавьте локальные реестры в список insecure

Пример полного файла:

```json
{
  "insecure-registries": [
    "localhost:5000",
    "localhost:5001",
    "localhost:5002"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Если вы хотите оставить только значения, относящиеся к проекту, достаточно минимального варианта:

```json
{
  "insecure-registries": [
    "localhost:5000",
    "localhost:5001",
    "localhost:5002"
  ]
}
```

### 3. Перезапустите Docker

#### systemd

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

#### SysV/init.d

```bash
sudo service docker restart
```

#### Альтернативно, если Docker запущен вручную

```bash
sudo systemctl restart docker
```

### 4. Проверьте, что настройки применились

```bash
docker info | grep -A3 "Insecure Registries"
```

Ожидаемый результат должен содержать:

```text
Insecure Registries:
  localhost:5000
  localhost:5001
  localhost:5002
```

### 5. Проверьте локальные реестры

```bash
curl http://localhost:5000/v2/
curl http://localhost:5001/v2/
curl http://localhost:5002/v2/
```

Ожидаемый ответ:

```json
{}
```

## Быстрый старт

### 1. Скопировать пример окружения

```bash
cp .env.example .env
```

### 2. Настроить Docker daemon

Выполните шаги из раздела выше: создайте `/etc/docker/daemon.json` и добавьте локальные реестры в `insecure-registries`.

### 3. Запустить контейнеры

```bash
docker compose up -d
```

### 4. Проверить состояние

```bash
docker compose ps
```

### 5. Проверить доступность реестров

```bash
curl http://localhost:5000/v2/
curl http://localhost:5001/v2/
curl http://localhost:5002/v2/
```

## Подробности по сервисам

### Docker Hub proxy

- порт: `5000`
- config: [config/docker.yml](./config/docker.yml)
- remote: `https://registry-1.docker.io`

### Quay proxy

- порт: `5001`
- config: [config/quay.yml](./config/quay.yml)
- remote: `https://quay.io`

### GHCR proxy

- порт: `5002`
- config: [config/ghcr.yml](./config/ghcr.yml)
- remote: `https://ghcr.io`

### Конфиги реестров

Файлы в директории [config](./config) задают параметры каждого registry:

- уровень логирования
- адрес и порт слушания
- удалённый upstream (remote URL)
- корневую директорию для хранения образов

## Использование

### Пуш образа в локальный реестр

```bash
docker tag my-image:latest localhost:5000/my-image:latest
docker push localhost:5000/my-image:latest
```

Аналогично для других реестров:

```bash
docker tag my-image:latest localhost:5001/my-image:latest
docker push localhost:5001/my-image:latest

docker tag my-image:latest localhost:5002/my-image:latest
docker push localhost:5002/my-image:latest
```

### Pull образа обратно

```bash
docker pull localhost:5000/my-image:latest
```

### Просмотр списка репозиториев

```bash
curl http://localhost:5000/v2/_catalog
curl http://localhost:5001/v2/_catalog
curl http://localhost:5002/v2/_catalog
```

## Команды управления

### Остановить контейнеры

```bash
docker compose down
```

### Остановить и удалить тома

```bash
docker compose down -v
```

### Посмотреть логи

```bash
docker compose logs -f docker-registry
docker compose logs -f quay-registry
docker compose logs -f ghcr-registry
```

### Перезапустить сервисы

```bash
docker compose restart
```

## Решение проблем

### Реестр не отвечает

```bash
docker compose ps
docker compose logs <service-name>
```

### Ошибка `x509` / `TLS` / `http: server gave HTTP response to HTTPS client`

Это обычно означает, что Docker daemon не настроен на insecure registry. Проверьте:

1. файл `/etc/docker/daemon.json`
2. список `insecure-registries`
3. перезапуск `docker` daemon
4. наличие корректного `localhost`/`127.0.0.1` в списке

### Ошибка доступа через прокси

Проверьте, что:

- `.env` содержит корректный `PROXY_URL`
- контейнеры получают переменные `HTTP_PROXY` и `HTTPS_PROXY`
- `NO_PROXY_LIST` включает `localhost` и `127.0.0.1`

### Потеря данных

Если требуется удалить данные реестра вместе с контейнерами:

```bash
docker compose down -v
```

## Безопасность и рекомендации

- Для локальной разработки использование HTTP и `insecure-registries` допустимо.
- Для продакшена лучше закрывать сервисы TLS и ограничивать доступ по сети.
- Не публикуйте реестры на публичный интерфейс без фильтрации доступа.
- Не храните реальные credentials/proxy-логины в репозитории — используйте локальный `.env` или безопасное хранение секретов.

## Проверка итоговой конфигурации

После настройки демон должен быть в рабочем состоянии:

```bash
docker compose up -d

docker compose ps

docker info | grep -A3 "Insecure Registries"

curl http://localhost:5000/v2/
curl http://localhost:5001/v2/
curl http://localhost:5002/v2/
```

Если все команды выполняются без ошибок, кластер готов к использованию.
