## Подключение worker-agent через JLNMP

0. Установим необходимые пакеты

```bash
sudo apt update -y
sudo apt install openjdk-17-jre jq -y 
```
Для начала нам необходимо получить api token для учетной записи, чтобы можно было работать через api 

1. ### Получение API-токена через Jenkins API

Для автоматизации получения секрета агента, сначала получим API-токен.

```bash
JENKINS_URL=jenkins.yc.home-local.site
# Получаем XML целиком
RESPONSE=$(curl -k -s \
  -u "admin:admin" \
  "https://${JENKINS_URL}/crumbIssuer/api/json" \
  -c cookies.txt)

# Извлекаем нужные части
CRUMB_FIELD=$(echo "$RESPONSE" | grep -oP '<crumbRequestField>\K[^<]+')
CRUMB_VALUE=$(echo "$RESPONSE" | grep -oP '<crumb>\K[^<]+')

# Формируем заголовок
CRUMB="${CRUMB_FIELD}:${CRUMB_VALUE}"
```
>🔐 Замените admin:admin на свои учётные данные. 


2. ### Сгенерируй новый API-токен

```bash
API_TOKEN=$(curl -k -s \
  -u "admin:admin" \
  -b cookies.txt \
  -H "$CRUMB" \
  --data "newTokenName=automation-token" \
  "https://${JENKINS_URL}/user/admin/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" \
  | jq -r '.data.tokenValue')
```
>✅ Токен будет использован для последующих API-запросов. 



3. ### Настройка ноды на Jenkins server

Настройте агента на мастере с помощью Jenkins Configuration as Code (JCASC).

```yaml
jenkins:
    nodes:
    - permanent:
      name: "agent-1"
      labelString: "linux docker build"
      remoteFS: "/home/ubuntu/jenkins-agent"
      numExecutors: 2
      launcher:
        inbound:
          webSocket: true
      mode: NORMAL
```

3. ### Получение секрета агента

После создания ноды, получите её секрет через API:

```bash
SECRET=$(curl -k -s   -u "admin:${API_TOKEN}"   "https://jenkins.yc.home-local.site/computer/agent-1/slave-agent.jnlp" | sed "s/.*<application-desc><argument>\([a-z0-9]*\).*/\1\n/")
echo ${SECRET}
```

4. ###  Ручной запуск агента (проверка)

Создадим директорию для агента

```bash
mkdir -p jenkins-agent && cd jenkins-agent
```

Скачаем агент

```bash
curl -sO https://jenkins.yc.home-local.site/jnlpJars/agent.jar
```

Попробуем запустить агент руками

```bash
java -jar agent.jar \
  -url https://jenkins.yc.home-local.site \
  -webSocket \
  -secret ${SECRET} \
  -name "agent-1" \
  -workDir "/home/ubuntu/jenkins-agent"
```
Вывод:

```bash
Aug 25, 2025 12:56:23 PM hudson.remoting.Launcher$CuiListener status
INFO: Connected
```

Обратите внимание имя агента должно собрать с именем агента, которое задали в Jenkins

5. ### Автоматизация: systemd-сервис

Перенесем `agent.jar` в `/usr/local/bin`

```bash
sudo mv agent.jar /usr/local/bin
```

Создадим файл сервиса `jenkins-agent.service`

```bash
sudo vim /etc/systemd/system/jenkins-agent.service
```

И внесем данные:

```bash
[Unit]
Description=Jenkins Agent
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/jenkins-agent
ExecStart=/usr/bin/java -jar /usr/local/bin/agent.jar \
  -url https://jenkins.yc.home-local.site \
  -webSocket \
  -secret ${SECRET} \
  -name agent-1 \
  -workDir /home/ubuntu/jenkins-agent
Restart=always
RestartSec=10
Environment=JAVA_OPTS=-Djava.awt.headless=true
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Затем перезагрузим юниты

```bash
sudo systemctl daemon-reload
```

И запустим сервис

```bash
sudo systemctl enable --now  jenkins-agent.service
```

Проверим сервис

```bash
sudo systemctl status  jenkins-agent.service
```

Если все хорош, вывод будет следующим

```bash
● jenkins-agent.service - Jenkins Agent
     Loaded: loaded (/etc/systemd/system/jenkins-agent.service; enabled; vendor preset: enabled)
     Active: active (running) since Mon 2025-08-25 12:08:57 UTC; 1min 3s ago
   Main PID: 7902 (java)
      Tasks: 44 (limit: 2316)
     Memory: 92.5M
     CGroup: /system.slice/jenkins-agent.service
             └─7902 /usr/bin/java -jar /usr/local/bin/agent.jar -url https://jenkins.yc.home-local.site -webSocket -secret bb1bd95c2810ac36034e884759702c7aeb0dc676812a1d4>

Aug 25 12:08:57 fhmg936atebr9ra3jlkt java[7902]: Aug 25, 2025 12:08:57 PM hudson.remoting.Launcher createEngine
Aug 25 12:08:57 fhmg936atebr9ra3jlkt java[7902]: INFO: Setting up agent: agent-1
Aug 25 12:08:58 fhmg936atebr9ra3jlkt java[7902]: Aug 25, 2025 12:08:58 PM hudson.remoting.Engine startEngine
Aug 25 12:08:58 fhmg936atebr9ra3jlkt java[7902]: INFO: Using Remoting version: 3309.v27b_9314fd1a_4
Aug 25 12:08:58 fhmg936atebr9ra3jlkt java[7902]: Aug 25, 2025 12:08:58 PM org.jenkinsci.remoting.engine.WorkDirManager initializeWorkDir
Aug 25 12:08:58 fhmg936atebr9ra3jlkt java[7902]: INFO: Using /home/ubuntu/jenkins-agent/remoting as a remoting work directory
Aug 25 12:08:58 fhmg936atebr9ra3jlkt java[7902]: Aug 25, 2025 12:08:58 PM hudson.remoting.Launcher$CuiListener status
Aug 25 12:08:58 fhmg936atebr9ra3jlkt java[7902]: INFO: WebSocket connection open
Aug 25 12:08:59 fhmg936atebr9ra3jlkt java[7902]: Aug 25, 2025 12:08:59 PM hudson.remoting.Launcher$CuiListener status
Aug 25 12:08:59 fhmg936atebr9ra3jlkt java[7902]: INFO: Connected
```