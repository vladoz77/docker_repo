# Docker Registry Proxy Cluster

Локальный набор Docker Registry v2 для работы с несколькими удалёнными реестрами через прокси. Проект позволяет запускать независимые экземпляры реестра для Docker Hub, GitHub Container Registry и Quay с отдельными портами и томами.

## Что входит в проект

Проект запускает три отдельных контейнера:

- Docker Hub proxy — доступен на `http://localhost:5000`
- Quay proxy — доступен на `http://localhost:5001`
- GHCR proxy — доступен на `http://localhost:5002`

Каждый экземпляр использует собственный конфигурационный файл и том данных.

## Требования

- Docker
- Docker Compose v2

## Структура проекта

```text
.
├── docker-compose.yaml
├── config/
│   ├── docker.yml
│   ├── ghcr.yml
│   └── quay.yml
└── README.md
```

## Быстрый старт

### 1. Запустить контейнеры

```bash
docker compose up -d
```

### 2. Проверить состояние

```bash
docker compose ps
```

### 3. Проверить доступность реестров

```bash
curl http://localhost:5000/v2/
curl http://localhost:5001/v2/
curl http://localhost:5002/v2/
```

Ожидаемый ответ для каждого сервиса:

```json
{}
```

## Конфигурация

### Основной compose-файл

Файл [docker-compose.yaml](docker-compose.yaml) описывает три сервиса:

- `docker-registry` — прокси к `https://registry-1.docker.io`
- `quay-registry` — прокси к `https://quay.io`
- `ghcr-registry` — прокси к `https://ghcr.io`

### Конфигурационные файлы

- [config/docker.yml](https://github.com/vladoz77/docker_repo/blob/master/config/docker.yml) — настройки для Docker Hub proxy
- [config/quay.yml](https://github.com/vladoz77/docker_repo/blob/master/config/quay.yml) — настройки для Quay proxy
- [config/ghcr.yml](https://github.com/vladoz77/docker_repo/blob/master/config/ghcr.yml) — настройки для GHCR proxy

Каждый файл задаёт:

- уровень логирования
- адрес и порт слушания
- remote URL удалённого реестра
- путь к файловому хранилищу

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
```

```bash
docker tag my-image:latest localhost:5002/my-image:latest
docker push localhost:5002/my-image:latest
```

### Pull образа обратно

```bash
docker pull localhost:5000/my-image:latest
```

## Команды

### Остановить контейнеры

```bash
docker compose down
```

### Остановить и удалить данные

```bash
docker compose down -v
```

### Посмотреть логи

```bash
docker compose logs -f docker-registry
docker compose logs -f quay-registry
docker compose logs -f ghcr-registry
```

### Просмотреть список репозиториев

```bash
curl http://localhost:5000/v2/_catalog
curl http://localhost:5001/v2/_catalog
curl http://localhost:5002/v2/_catalog
```

## Томы и данные

Проект использует отдельные тома для каждого реестра:

- `docker_data`
- `quay_data`
- `ghcr_data`

Данные сохраняются на хосте и остаются доступными после перезапуска контейнеров.

## Безопасность

- Для локальной разработки проект использует HTTP.
- Для продакшена стоит включить TLS и защиту доступа.
- Если Docker на вашей машине не принимает незащищённые реестры, добавьте соответствующие адреса в `insecure-registries`.

## Решение проблем

### Реестр не отвечает

```bash
docker compose ps
docker compose logs <service-name>
```

### Ошибка при работе с незащищённым реестром

Если Docker отклоняет push/pull к локальному реестру, добавьте в `/etc/docker/daemon.json` записи вида:

```json
{
  "insecure-registries": ["localhost:5000", "localhost:5001", "localhost:5002"]
}
```

После этого перезапустите Docker.
