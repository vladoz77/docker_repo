# Marzban + Nginx + WARP Docker Setup

## Описание

Этот проект предоставляет полностью настроенную инфраструктуру для запуска **Marzban** с поддержкой **Xray REALITY**, **Nginx** в качестве reverse proxy и **Cloudflare WARP** для обхода блокировок. Также используется **MySQL** для хранения данных.

---

## 📁 Структура проекта

```
.
├── docker-compose.yaml
├── marzban
│   └── xray_config.json
├── nginx
│   ├── nginx.conf
│   └── proxy.conf
└── .env
```

---

## 🧩 Компоненты

| Компонент | Описание |
|----------|----------|
| **Marzban** | Панель управления Xray/V2Ray |
| **MySQL** | База данных для Marzban |
| **Nginx** | Reverse proxy с поддержкой SNI routing |
| **WARP** | SOCKS5 прокси от Cloudflare для обхода ограничений |
| **Xray REALITY** | Современный протокол для обхода DPI |

---

## 🛠️ Установка и настройка

### 1. Клонирование репозитория

```bash
git clone https://github.com/yourusername/marzban-docker.git
cd marzban-docker
```

---

### 2. Настройка `.env` файла

Откройте файл `.env` и измените следующие параметры:

```env
# Marzban - настройки администратора панели
SUDO_USERNAME=admin
SUDO_PASSWORD=your_secure_password

# MySQL - настройки базы данных
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_PASSWORD=your_secure_db_password

# Домен для подписок
XRAY_SUBSCRIPTION_URL_PREFIX=https://yourdomain.com
```

> ⚠️ **Важно**: Используйте надежные пароли.

---

### 3. Генерация ключей REALITY

#### Генерация privateKey и publicKey:

```bash
docker exec marzban xray x25519
```

Результат будет примерно таким:
```
Private key: 4ErnwFwwdsR0eq2np73JuPysFiEVi1xIVNKpRezc6TE
Public key: 7kD0U9HhJkLmN8pQrS2tV4wXyZ1aB3cD5eF6gH7jK9m
```

Сохраните `Private key` для использования в конфигурации Xray.

#### Генерация shortId:

```bash
openssl rand -hex 8
```

Пример результата: `8d9b438b097eb1ca`

---

### 4. Выбор сайта для маскировки

Для правильной работы REALITY необходимо выбрать подходящий сайт для маскировки. Используйте утилиту **RealiTLScanner**:

1. Скачайте утилиту:
```bash
wget https://github.com/XTLS/RealiTLScanner/releases/latest/download/RealiTLScanner-linux-64
chmod +x RealiTLScanner-linux-64
```

2. Запустите сканер:
```bash
./RealiTLScanner-linux-64 -addr ваш_адрес_сервера
```

3. Выберите подходящий домен из результатов и используйте его в конфигурации.

---

### 5. Установка Nginx с модулем stream

Для работы SNI routing необходим модуль `ngx_stream_module`. Вот несколько способов установки:


#### Установка на Ubuntu/Debian

```bash
# Установка Nginx с модулем stream
sudo apt update
sudo apt install nginx-full

# Проверка наличия модуля
nginx -V 2>&1 | grep -o with-stream
```

#### Компиляция из исходников

```bash
# Установка зависимостей
sudo apt install build-essential libpcre3-dev zlib1g-dev

# Скачивание исходников Nginx
wget http://nginx.org/download/nginx-1.24.0.tar.gz
tar -zxpf nginx-1.24.0.tar.gz
cd nginx-1.24.0

# Конфигурация с модулем stream
./configure --with-stream --with-http_ssl_module --with-http_v2_module

# Компиляция и установка
make
sudo make install
```

#### Использование готовых пакетов

Для некоторых дистрибутивов доступны пакеты с полной сборкой:

```bash
# CentOS/RHEL
sudo yum install nginx-mod-stream

# Затем в nginx.conf добавьте:
load_module modules/ngx_stream_module.so;
```

---

### 6. Настройка Xray REALITY

Откройте файл `marzban/xray_config.json` и замените следующие значения:

- `"privateKey"` — ваш приватный ключ из шага 3
- `"shortIds"` — ваш shortId из шага 3
- `"dest"` — выбранный сайт для маскировки
- `"serverNames"` — домены для маскировки

Пример:
```json
"realitySettings": {
  "show": false,
  "dest": "www.tradingview.com:443",
  "xver": 0,
  "serverNames": [
    "tradingview.com",
    "www.tradingview.com"
  ],
  "privateKey": "4ErnwFwwdsR0eq2np73JuPysFiEVi1xIVNKpRezc6TE",
  "shortIds": [
    "8d9b438b097eb1ca"
  ]
}
```

---

### 7. Настройка SSL-сертификатов

Для работы Nginx необходим SSL-сертификат. Используйте Let's Encrypt:

```bash
sudo certbot certonly --standalone -d yourdomain.com
```

Убедитесь, что пути в `nginx/proxy.conf` соответствуют расположению ваших сертификатов:

```nginx
ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
```

---

### 8. Настройка домена

Замените `marzban.nd.home-local.site` на ваш домен в следующих файлах:

- `nginx/nginx.conf`
- `nginx/proxy.conf`
- `.env`

---

### 9. Запуск проекта

```bash
docker-compose up -d
```

---

## 🔧 Полезные команды

### Просмотр логов

```bash
docker logs marzban
docker logs mysql
docker logs warp_v3
```

### Перезапуск сервисов

```bash
docker-compose restart
```

### Остановка

```bash
docker-compose down
```

---

## 🌐 Доступ к панели

После запуска перейдите по адресу:

```
https://yourdomain.com/dashboard
```

Логин и пароль указаны в `.env`:

```
Username: admin
Password: your_secure_password
```

---

## 🧪 Тестирование

После настройки создайте тестового пользователя в панели Marzban и проверьте подключение через клиент Xray или V2Ray.

---

## 📌 Примечания

- Убедитесь, что порты `80`, `443`, `10000` открыты.
- Если используете локальный домен (например `.home-local.site`), настройте его в локальном DNS.
- Для продакшена рекомендуется включить fail2ban и настроить резервное копирование базы данных.

