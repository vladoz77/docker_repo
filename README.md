# Docker Repo

Репозиторий с набором готовых `docker compose` проектов для homelab, инфраструктуры, мониторинга, прокси, CI/CD и медиа-сервисов.

## Что внутри

В репозитории есть как простые одиночные сервисы, так и составные стеки:

- reverse proxy и сетевые сервисы;
- мониторинг и логирование;
- CI/CD и DevOps-инструменты;
- хранилища и секреты;
- медиа- и VPN-проекты;
- локальная Kubernetes-среда на базе Docker.

## Быстрый старт

Общий сценарий запуска почти везде одинаковый:

```bash
cd <project-dir>
docker compose up -d
docker compose ps
docker compose logs -f
```

Для остановки:

```bash
docker compose down
```

Перед запуском проверьте:

- нужен ли файл `.env`;
- нужны ли домены, сертификаты или запись в `hosts`;
- используется ли внешняя Docker-сеть;
- есть ли отдельный `README` внутри папки проекта.

## Каталог проектов

### Reverse Proxy и сеть

- [`traefik/`](./traefik) — отдельный reverse proxy на `Traefik` с TLS, dashboard и метриками. Подходит как базовый входной шлюз для других контейнеров. Документация: [`traefik/Readme.md`](./traefik/Readme.md).
- [`nginx-proxy-manager/`](./nginx-proxy-manager) — `Nginx Proxy Manager` с веб-интерфейсом управления reverse proxy и SSL. Открывает `80`, `81`, `443`. Документация: [`nginx-proxy-manager/readme`](./nginx-proxy-manager/readme).
- [`adguard-home/`](./adguard-home) — локальный DNS-фильтр и блокировщик рекламы на `AdGuard Home`. Экспортирует DNS и web-интерфейс.
- [`dnsmasq/`](./dnsmasq) — лёгкий DNS-сервис на `dnsmasq` для локальной сети и простых резолвинг-сценариев.
- [`nfs/`](./nfs) — NFS-сервер в контейнере для шаринга данных по сети. Документация: [`nfs/readme.md`](./nfs/readme.md).

### Мониторинг и логирование

- [`prometheus+grafana/`](./prometheus+grafana) — классический стек мониторинга: `Prometheus`, `Grafana`, `Alertmanager`, `node-exporter`, `cAdvisor`. Подходит для наблюдения за хостом и контейнерами.
- [`victoria-metrics/`](./victoria-metrics) — стек мониторинга на `VictoriaMetrics` с `vmalert`, `Alertmanager`, `Grafana` и `Karma`. Документация: [`victoria-metrics/Readme.md`](./victoria-metrics/Readme.md).
- [`grafana-stack/`](./grafana-stack) — современный observability-стек: `Traefik`, `Prometheus`, `Alertmanager`, `Loki`, `Grafana`. В папке есть конфиги и systemd-настройка для `Alloy`.
- [`blackbox exporter/`](./blackbox%20exporter) — `Blackbox Exporter` и `Prometheus` для HTTP/TCP/ICMP probe-проверок внешних и внутренних сервисов. Документация: [`blackbox exporter/README.md`](./blackbox%20exporter/README.md).
- [`elasticsearch/`](./elasticsearch) — кластер `Elasticsearch` из трёх узлов с `Kibana` и `Vector` для централизованного сбора и анализа логов. Документация: [`elasticsearch/README.md`](./elasticsearch/README.md).

### CI/CD и DevOps

- [`jenkins/`](./jenkins) — `Jenkins` в Docker, есть вариант с `Traefik`, кастомный `Dockerfile`, `JCasC` и материалы по агентам/Vault. Документация: [`jenkins/README.md`](./jenkins/README.md).
- [`gitlab/`](./gitlab) — `GitLab CE` вместе с `gitlab-runner` для локального Git-сервера и CI.
- [`sonarqube/`](./sonarqube) — `SonarQube Community` c `PostgreSQL` для статического анализа кода.
- [`nexus/`](./nexus) — `Sonatype Nexus3` для хранения артефактов и Docker-образов. Проброшены web-порт и registry-порты. Документация: [`nexus/Readme.md`](./nexus/Readme.md).
- [`portrain/`](./portrain) — `Portainer CE` для управления Docker через UI. В папке опечатка в имени, но сам проект запускает именно `Portainer`.

### Безопасность, доступ и хранилища

- [`vault/`](./vault) — `HashiCorp Vault` для хранения секретов, с примерами `unseal`, `AppRole` и интеграции для Terraform. Документация: [`vault/Readme.md`](./vault/Readme.md).
- [`authentik/`](./authentik) — self-hosted `Authentik` для SSO/IdP, использует `PostgreSQL` и `Redis`. Документация: [`authentik/Readme.md`](./authentik/Readme.md).
- [`minio/`](./minio) — `MinIO` как S3-совместимое объектное хранилище. Открывает API на `9000` и web-console на `9001`. Документация: [`minio/Readme.md`](./minio/Readme.md).

### Медиа, VPN и пользовательские сервисы

- [`3x-ui/`](./3x-ui) — панель `3x-ui` за `Traefik` с HTTPS, маршрутами для подписок, `trojan/ws` и `VLESS/XHTTP/REALITY`. Документация: [`3x-ui/README.md`](./3x-ui/README.md).
- [`marzban/`](./marzban) — стек `Marzban` + `MySQL` + `WARP` для управления Xray/V2Ray и обхода ограничений. Документация: [`marzban/Readme.md`](./marzban/Readme.md).
- [`lampac/`](./lampac) — простой запуск `Lampac` без reverse proxy. Документация: [`lampac/Readme.md`](./lampac/Readme.md).
- [`lampac-traefik/`](./lampac-traefik) — `Lampac` за `Traefik` с HTTPS и Let's Encrypt. Документация: [`lampac-traefik/Readme.md`](./lampac-traefik/Readme.md).
- [`torrserv/`](./torrserv) — `TorrServer` для потоковой работы с торрентами по HTTP. Документация: [`torrserv/Readme.md`](./torrserv/Readme.md).
- [`rtmp-server/`](./rtmp-server) — RTMP-сервер на базе `nginx` с кастомным `Dockerfile`; подходит для приёма и ретрансляции видеопотоков. Открывает `1935` и `8080`.

### Kubernetes поверх Docker

- [`kind/`](./kind) — конфигурация локального Kubernetes-кластера на `kind` с одной `control-plane` и тремя `worker`-нодами. Это не `docker compose` проект, но он тоже использует Docker как основу. Документация: [`kind/Readme.md`](./kind/Readme.md).

## Как ориентироваться в репозитории

- почти в каждой папке лежит свой `docker-compose.yaml` или `docker-compose.yml`;
- часть проектов рассчитана на локальный домен вида `*.home.local` или `*.home-local.site`;
- некоторые compose-файлы используют внешние сети, например `proxy` или `nginx_net`;
- документация в подпапках написана в разном стиле и с разной глубиной, поэтому корневой `README` лучше использовать как индекс.

## Полезные команды

Показать итоговую конфигурацию проекта:

```bash
docker compose config
```

Обновить образы и перезапустить сервис:

```bash
docker compose pull
docker compose up -d
```

Проверить контейнеры:

```bash
docker compose ps
docker ps
```
