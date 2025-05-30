# Проект Мониторинга (VictoriaMetrics + Alertmanager + Grafana)

Простой и мощный стек мониторинга, построенный на базе VictoriaMetrics , Prometheus scrape config , Alertmanager , Grafana и Karma для визуализации алертов.

- VictoriaMetrics — высокопроизводительное временное хранилище метрик.
- VMAlert — обработка правил и отправка алертов через Alertmanager.
- Alertmanager — маршрутизация и управление уведомлениями.
- Grafana — визуализация метрик и дашборды.
- Karma — UI для отображения активных алертов из Alertmanager.

## Структура проекта

```plain-text
monitoring/
├── docker-compose.yaml
├── victoriametrics/
│   └── scrape.yaml        # Конфигурация скрапинга метрик
├── vmalert/
│   └── rules/             # Директория с alert и recording rules
├── alertmanager/
│   └── alertmanager.yaml  # Конфиг маршрутов и получателей алертов
├── grafana/
│   ├── datasources.yaml   # Настройки источников данных
│   ├── dashboards.yaml    # Автопровижинг дашбордов
│   └── victoriametrics-dashboards/  # JSON файлы дашбордов
└── README.md              # Этот файл
```

## Запуск проекта

1. Убедитесь, что установлен Docker и Docker Compose .
2. Выполните команду:

```bash
docker compose up -d
```

3. Откройте следующие интерфейсы в браузере:

| **Сервис** | **URL** |
| --- | --- |
| VictoriaMetrics | http://localhost:8428 |
| VMAlert | http://localhost:8880 |
| Grafana | http://localhost:3000 |
| Alertmanager | http://localhost:9093 |
| Karma | http://localhost:8080 |

>[!Note]
>По умолчанию учетные данные для Grafana: admin/admin. Измените их при первом входе. 

## Метрики

Сейчас собираются метрики с компонентов самого стека:

- VictoriaMetrics (/metrics)
- VMAlert (/metrics)
- Grafana (/metrics)

Вы можете добавить дополнительные job_name в `victoriametrics/scrape.yaml`, чтобы собирать метрики с ваших сервисов.

## Алерты

Правила алертов и рекординг правила в формате `.yaml` должны быть размещены в директории `vmalert/rules/`

Пример содержимого правила:

```yaml
groups:
  - name: example-alert
    rules:
      - record: job:up:sum
        expr: sum by (job) (up)
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.job }} is down"
          description: "Instance {{ $labels.instance }} has been down for more than 1 minute."
```

## Дашборды Grafana

Для автоматического импорта дашбордов положите `.json` файлы в `grafana/victoriametrics-dashboards/`

## Уведомления

Текущая конфигурация Alertmanager направляет все алерты в blackhole (ничего не отправляется). Чтобы добавить уведомления:

1. Обновите alertmanager/alertmanager.yaml с реальными получателями (email, Slack, Telegram и т.д.)
2. Перезапустите контейнер Alertmanager:

```bash
docker compose restart alertmanager
```

## Хранение данных

- Данные VictoriaMetrics сохраняются в Docker volume vmstorage.
- Данные Grafana сохраняются в Docker volume grafana.