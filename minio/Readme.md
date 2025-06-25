# Установка и настройка mvp minio

## Установка Docker

Добавьте официальный GPG-ключ Docker:

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Добавьте репозиторий в источники Apt:

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

Установите пакеты Docker:

```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

Добавить нашего пользователя в группу `docker`

```bash
sudo usermod -aG docker ${USER}
```

## Установка minio через Docker compose

Создадим директорию `minio` с файлами нашего проекта

```bash
mkdir minio && cd minio
```

Создадим `.env`, чтобы хранить конфигурационные переменные:

```bash
vim .env
```

```bash
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=password
```

Создадим файл `docker-compose.yaml` и напишем следующее:

```bash
vim docker-compose.yaml
```

```yaml
services:
  minio:
    container_name: minio
    image: quay.io/minio/minio
    command: server /data --console-address ":9001"
    restart: always
    volumes:
      - minio-data:/data
    environment:
      - MINIO_ROOT_USER=${MINIO_ROOT_USER}
      - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
    ports:
      - 9000:9000
      - 9001:9001

volumes:
  minio-data:
networks:
  minio-network:
```

где:

- `image`: Используется официальный образ MinIO с Quay.io
- `command`: Запуск сервера с указанием директории данных `/data` и отдельного порта для веб-консоли (--console-address)
- `volumes`: Сохраняет данные на хосте в именованном томе `minio-data`
- `environment`: Переменные окружения загружаются из `.env` файла
- `ports`: Доступ к S3 API через 9000, к веб-интерфейсу через 9001
- `restart`: Автоматически перезапускает контейнер при падении или перезагрузке системы
- `networks`: Контейнер подключается к пользовательской сети minio-network

Запустим `minio` командой

```bash
docker compose up -d
```

Посмотрим логи

```bash
docker logs minio -f
```

Увидим следующее:

```bash
INFO: Formatting 1st pool, 1 set(s), 1 drives per set.
INFO: WARNING: Host local has more than 0 drives of set. A host failure will result in data becoming unavailable.
MinIO Object Storage Server
Copyright: 2015-2025 MinIO, Inc.
License: GNU AGPLv3 - https://www.gnu.org/licenses/agpl-3.0.html
Version: RELEASE.2025-05-24T17-08-30Z (go1.24.3 linux/amd64)

API: http://172.18.0.2:9000  http://127.0.0.1:9000
WebUI: http://172.18.0.2:9001 http://127.0.0.1:9001

Docs: https://docs.min.io
```

## Установим mc client

Загрузите `mc client` и установите его в папку, включенную в системный PATH, например `/usr/local/bin`.

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/mc
```

Используйте команду mc alias set, чтобы создать новый псевдоним `minio-local`, связанный с нашей локальной установкой.

```bash
mc alias set minio-local http://127.0.0.1:9000 admin password
```

Вывод:

```bash
mc: Configuration written to `/home/vagrant/.mc/config.json`. Please update your access credentials.
mc: Successfully created `/home/vagrant/.mc/share`.
mc: Initialized share uploads `/home/vagrant/.mc/share/uploads.json` file.
mc: Initialized share downloads `/home/vagrant/.mc/share/downloads.json` file.
Added `minio-local` successfully.
```

Проверим подключение:

```bash
mc admin info minio-local
```

Вывод:

```bash
●  127.0.0.1:9000
   Uptime: 33 minutes
   Version: 2025-05-24T17:08:30Z
   Network: 1/1 OK
   Drives: 1/1 OK
   Pool: 1

┌──────┬───────────────────────┬─────────────────────┬──────────────┐
│ Pool │ Drives Usage          │ Erasure stripe size │ Erasure sets │
│ 1st  │ 6.5% (total: 115 GiB) │ 1                   │ 1            │
└──────┴───────────────────────┴─────────────────────┴──────────────┘

1 drive online, 0 drives offline, EC:0
```

Создадим бакет `plane`

```bash
mc mb minio-local/plane
```
Вывод:

```bash
Bucket created successfully `minio-local/plane`.
```

Последним шагом со стороны Minio является создание пользователя, который мы будем использовать для доступа к этому бакету, а также определение соответствующих разрешений, чтобы доступ был ограничен только этим бакетом и объектами, содержащимися в нем.

```bash
mc admin user add minio-local plane password
```

Вывод:

```bash
Added user `plane` successfully.
```

Создайте файл `plane-policy.json`

```json
cat > /tmp/plane-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::plane",
                "arn:aws:s3:::plane/*"
            ]
        }
    ]
}
EOF
```

Примените политику `plane-policy.json`

```bash
mc admin policy create minio-local plane-policy  /tmp/plane-policy.json
```

Вывод:

```bash
Created policy `plane-policy` successfully.
```

Свяжите политику `plane-policy.json` с пользователем **plane**

```bash
mc admin policy attach minio-local plane-policy --user plane
```
вывод:

```bash
Attached Policies: [plane-policy]
To User: plane
```
Создать сервисную учетную запись для пользователя **plane**

```bash
mc admin user svcacct add minio-local plane --name plane-user --description "User for plane"
```

Запомните **Access Key** and **Secret Key**

```bash
Access Key: *****
Secret Key: *****
Expiration: no-expir
```

## Проверка

### Установим AWS CLI

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" --output "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

При необходимости установите `unzip`

```bash
sudo apt install unzip
```

### Настроим подключение к нашему minio

```bash
aws configure
AWS Access Key ID [None]: *****
AWS Secret Access Key [None]: *****
Default region name [None]: us-east-1
Default output format [None]: ENTER
```

Дополнительно включите версию подписи AWS «4» для сервера MinIO.

```bash
aws configure set default.s3.signature_version s3v4
```

Также настроим `endpoint_url` и укажим наш адрес сервера

```bash
aws configure set endpoint_url http://192.168.56.50:9000
```

### Проверка

Загрузим файл в бакет:

```bash
aws s3 cp pod.yaml s3://plane
```

Посмотрим бакет:

```bash
aws s3 ls plane
2025-06-04 10:26:56          0 pod.yaml
```

Удалим файл в бакете

```bash
aws s3 rm s3://plane/pod.yaml
delete: s3://plane/pod.yaml
```