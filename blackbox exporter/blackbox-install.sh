#!/bin/bash

# Script to install Docker and run blackbox-exporter with restricted access
set -e  

# IP, с которого разрешаем доступ
ALLOWED_IP="172.16.10.1"

# Проверка, что скрипт запущен от root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or use sudo"
  exit 1
fi

# Установка Docker, если не установлен
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
else
    echo "Docker is already installed."
fi

# Запуск Docker
echo "Starting Docker service..."
systemctl enable --now docker

# Создание директории для конфигурации blackbox-exporter
echo "Creating directory for blackbox-exporter configuration..."
mkdir -p ~/blackbox-exporter

# Создание конфигурационного файла
echo "Creating blackbox-exporter configuration file..."
cat > ~/blackbox-exporter/blackbox.yml << EOF
modules:
  https_endpoint:
    prober: http
    timeout: 15s
    http:
      method: GET
      valid_http_versions:
      - HTTP/1.1
      - HTTP/2.0
      fail_if_not_ssl: true
      no_follow_redirects: false
      ip_protocol_fallback: false
      preferred_ip_protocol: ip4
EOF

# Запуск контейнера blackbox-exporter
if [ "$(docker ps -q -f name=blackbox-exporter)" ]; then
    echo "blackbox-exporter container is already running."
else
    echo "Running blackbox-exporter container..."
    docker run -d --name blackbox-exporter \
      -p 9115:9115 \
      -v ~/blackbox-exporter/blackbox.yml:/etc/blackbox_exporter/blackbox.yml \
      prom/blackbox-exporter --config.file=/etc/blackbox_exporter/blackbox.yml
fi
echo "blackbox-exporter is running."

# Настройка iptables для ограничения доступа
echo "Configuring iptables to allow only $ALLOWED_IP..."

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i docker0 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp -s $ALLOWED_IP --dport 22 -j ACCEPT
iptables -A INPUT -p tcp -s $ALLOWED_IP --dport 9115 -j ACCEPT
iptables -A FORWARD -o docker0 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i docker0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "iptables configured. Access restricted to $ALLOWED_IP."
echo "Setup completed successfully."
