**Blackbox Exporter Docker**

- **Описание**: Репозиторий содержит конфигурацию и `docker-compose` для запуска Prometheus Blackbox Exporter.

**Файлы**
- **`blackbox.yaml`**: Конфигурация модулей для Blackbox Exporter.
- **`docker-compose.yaml`**: Сервис для запуска Blackbox Exporter в контейнере.

**Требования**
- **Docker**: Установлен Docker Engine.
- **Docker Compose**: Рекомендуется использовать встроенный `docker compose` или `docker-compose`.

**Быстрый Старт**
- **Запуск**: Выполните в корне репозитория:

```bash
cd "Blackbox exporter"
docker compose up -d
```

- **Альтернатива (старый синтаксис)**:

```bash
docker-compose up -d
```

**Проверка работы**
- **Просмотр логов**:

```bash
docker compose logs -f
```

- **Метрики**: По умолчанию Blackbox Exporter экспортирует метрики на порту `9115`.
Откройте в браузере или проверьте с помощью curl:

```bash
curl http://localhost:9115/metrics
```

**Интеграция с Prometheus**
- **Пример scrape-конфигурации** (в `prometheus.yml`):

```yaml
- job_name: 'blackbox'
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets:
      - https://example.com
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: localhost:9115
```

**Настройка модулей**
- **`blackbox.yaml`** содержит модули (например, `http_2xx`, `tcp_connect` и т.д.).
- Для изменения модулей отредактируйте `blackbox.yaml` и перезапустите сервис:

```bash
docker compose restart
```

или принудительно пересоберите и запустите:

```bash
docker compose up -d --build --force-recreate
```

**Отладка**
- **Проверка контейнеров**:

```bash
docker ps --filter "name=blackbox"
```

- **Проверка портов**:

```bash
ss -tlnp | grep 9115
```

**Советы**
- **Модули**: Используйте разные модули для разных типов проверок (HTTP, TCP, ICMP).
- **Безопасность**: При проверке внутренних сервисов убедитесь, что Blackbox имеет доступ к необходимым хостам.


