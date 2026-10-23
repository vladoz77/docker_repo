#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

# Check if run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Please create the .env file with the required configuration"
    exit 1
fi

set -a; source .env; set +a
: "${STEPCA_HOST:?STEPCA_HOST is not set in .env}"
ROOT_CA_CERT_PATH="${ROOT_CA_CERT_PATH:-./certs/root_ca.crt}"
CA_URL="https://${STEPCA_HOST}"      

# docker-сеть должна существовать
docker network inspect "${DOCKER_NETWORK}" >/dev/null 2>&1 || {
    echo "Создай сеть: docker network create --subnet <CIDR> ${DOCKER_NETWORK}"
    exit 1
}

# check if TRAEFIK_BIND_IP is assigned to any interface
if [ "${TRAEFIK_BIND_IP:-0.0.0.0}" != "0.0.0.0" ] && \
   ! ip -4 -o addr show | grep -q " ${TRAEFIK_BIND_IP}/"; then
    echo "Адрес ${TRAEFIK_BIND_IP} не назначен ни на один интерфейс (dummy0 поднят?)"
    exit 1
fi

# Render traefik.yml from template
if ! command -v envsubst >/dev/null; then
    echo "envsubst not found: dnf install gettext"
    exit 1
fi
if [ ! -f config/traefik.yml.tpl ]; then
    echo "config/traefik.yml.tpl not found"
    exit 1
fi
envsubst '${STEPCA_HOST}' < config/traefik.yml.tpl > config/traefik.yml
echo "config/traefik.yml rendered"

# Start step-ca only, wait for it to be ready, then export root CA and fingerprint
echo "Запуск ${STEPCA_CONTAINER_NAME}..."
docker compose up -d --wait --wait-timeout 120 step-ca

# Export root CA and fingerprint
mkdir -p "$(dirname "${ROOT_CA_CERT_PATH}")"
docker exec "${STEPCA_CONTAINER_NAME}" cat /home/step/certs/root_ca.crt > "${ROOT_CA_CERT_PATH}"
FINGERPRINT="$(docker exec "${STEPCA_CONTAINER_NAME}" \
    step certificate fingerprint /home/step/certs/root_ca.crt)"

# Add root CA to system trust store
if command -v update-ca-trust >/dev/null; then            # Rocky / RHEL
    install -D -m 0644 "${ROOT_CA_CERT_PATH}" /etc/pki/ca-trust/source/anchors/homelab_root_ca.crt
    update-ca-trust
elif command -v update-ca-certificates >/dev/null; then  # Debian / Ubuntu
    install -D -m 0644 "${ROOT_CA_CERT_PATH}" /usr/local/share/ca-certificates/homelab_root_ca.crt
    update-ca-certificates
fi

# Start traefik and other services
echo "Запуск остальных сервисов..."
docker compose up -d --wait --wait-timeout 120

cat <<EOF

================ Homelab CA ================
CA URL:        ${CA_URL}
ACME:          ${CA_URL}/acme/acme/directory
Fingerprint:   ${FINGERPRINT}
Root CA:       ${ROOT_CA_CERT_PATH}

Добавить хост (вариант 1, со step CLI):
  step ca bootstrap --ca-url ${CA_URL} --fingerprint ${FINGERPRINT} --install

Добавить хост (вариант 2, без step, с проверкой отпечатка):
  curl -sk ${CA_URL}/roots.pem -o /tmp/root_ca.crt
  [ "\$(openssl x509 -in /tmp/root_ca.crt -noout -fingerprint -sha256 | cut -d= -f2 | tr -d : | tr A-F a-f)" = "${FINGERPRINT}" ] \\
    && sudo install -m 0644 /tmp/root_ca.crt /etc/pki/ca-trust/source/anchors/homelab_root_ca.crt \\
    && sudo update-ca-trust
============================================
EOF