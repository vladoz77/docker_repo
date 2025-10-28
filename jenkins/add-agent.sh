#!/bin/bash

set -euo pipefail

# === Настройки ===
JENKINS_URL="http://10.84.62.136:8080"
AGENT_NAME="lxc-jenkins-agent"
JENKINS_USER="admin"
JENKINS_PASS="admin"          
AGENT_USER="vlad"
AGENT_HOME="/home/${AGENT_USER}/jenkins-agent"
AGENT_JAR_PATH="${AGENT_HOME}/agent.jar" 
SYSTEMD_UNIT_PATH="/etc/systemd/system/jenkins-agent.service"

# === Установка Java (если не установлена) ===
if ! command -v java &> /dev/null; then
    echo "Java не найдена. Устанавливаем OpenJDK 17..."
    if command -v dnf &> /dev/null; then
        dnf install -y java-17-openjdk-headless
    elif command -v apt &> /dev/null; then
        apt update
        apt install -y openjdk-17-jre-headless
    else
        echo "❌ Неизвестный пакетный менеджер. Установите Java вручную."
        exit 1
    fi
else
    echo "✅ Java уже установлена: $(java -version 2>&1 | head -1)"
fi

# === 0. Создаём рабочую директорию, если не существует ===
echo "Создаём рабочую директорию: ${AGENT_HOME}"
install -d -m 755 -o "${AGENT_USER}" -g "${AGENT_USER}" "${AGENT_HOME}"

# === 1. Скачиваем agent.jar ===
echo "Скачиваем agent.jar из ${JENKINS_URL}/jnlpJars/agent.jar..."
curl -s -u "${JENKINS_USER}:${JENKINS_PASS}" \
  "${JENKINS_URL}/jnlpJars/agent.jar" \
  -o "${AGENT_JAR_PATH}"

# Меняем владельца, чтобы агент мог читать jar
chown "${AGENT_USER}:${AGENT_USER}" "${AGENT_JAR_PATH}"
chmod 644 "${AGENT_JAR_PATH}"

echo "✅ agent.jar сохранён в ${AGENT_JAR_PATH}"

# === 2. Получаем secret из JNLP ===
echo "Получаем secret для агента '${AGENT_NAME}'..."

JNLP_CONTENT=$(curl -k -s -u "${JENKINS_USER}:${JENKINS_PASS}" \
  "${JENKINS_URL}/computer/${AGENT_NAME}/slave-agent.jnlp")

SECRET=$(echo "$JNLP_CONTENT" | sed -n 's/.*<argument>\([a-z0-9]\{64\}\)<\/argument>.*/\1/p')

if [ -z "$SECRET" ]; then
  echo "❌ Ошибка: не удалось извлечь secret."
  echo "Возможно, агент '${AGENT_NAME}' не создан в Jenkins или неверные учётные данные."
  echo "Ответ от Jenkins:"
  echo "$JNLP_CONTENT" | head -n 20
  exit 1
fi

echo "✅ Secret получен (первые 8 символов): ${SECRET:0:8}..."

# === 3. Создаём systemd unit ===
echo "Генерируем unit-файл: ${SYSTEMD_UNIT_PATH}"

cat > "${SYSTEMD_UNIT_PATH}" <<EOF
[Unit]
Description=Jenkins Agent (${AGENT_NAME})
After=network.target

[Service]
Type=simple
User=${AGENT_USER}
WorkingDirectory=${AGENT_HOME}
ExecStart=/usr/bin/java -jar ${AGENT_JAR_PATH} \\
  -url ${JENKINS_URL} \\
  -webSocket \\
  -noCertificateCheck \\
  -secret ${SECRET} \\
  -name ${AGENT_NAME} \\
  -workDir ${AGENT_HOME}
Restart=always
RestartSec=10
Environment=JAVA_OPTS=-Djava.awt.headless=true
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# === 4. Применяем и запускаем службу ===
echo "Перезагружаем systemd и запускаем службу..."

systemctl daemon-reload
systemctl enable --now jenkins-agent.service

echo "✅ Агент настроен и запущен!"
echo "Логи: journalctl -u jenkins-agent -f"