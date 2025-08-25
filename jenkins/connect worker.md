## Подключение worker-agent через JLNMP

Для начала нам необходимо получить api token для учетной записи, чтобы можно было работать через api 

1. ### Получи CSRF-токен

```bash
CRUMB=$(curl -k "https://admin:admin@jenkins.yc.home-local.site/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)" -c cookies.txt)
```

2. ### Сгенерируй новый API-токен

```bash
API_TOKEN=$(curl -k 'https://admin:admin@jenkins.yc.home-local.site/user/admin/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken' \
--data 'newTokenName=kb-token' -b cookies.txt -H $CRUMB | jq -r '.data.tokenValue')
```
3. ### Настройка ноды на Jenkins server

Необходимо настроить ноду, которую будем подключать. 
Для автоматической настройки ноды, я использую плагин JCAS

Создам файлик Jenkins.yaml и добавляем такую конфигурацию:

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

3. ### Получим секрет

Для подключени worker нам необходим секрет, можно получить через API

```bash
SECRET=$(curl -k -s   -u "admin:${API_TOKEN}"   "https://jenkins.yc.home-local.site/computer/agent-1/slave-agent.jnlp" | sed "s/.*<application-desc><argument>\([a-z0-9]*\).*/\1\n/")
```

4. ### Подключаем агент

```bash
curl -sO https://jenkins.yc.home-local.site/jnlpJars/agent.jar
java -jar agent.jar -url https://jenkins.yc.home-local.site/ -secret ${SECRET} -name "agent-1" -webSocket -workDir "/home/ubuntu/jenkins-age
nt"
```

5. ### Создадим юнит systemd

Создадим папку `/home/ubuntu/jenkins-agent`

```bash
sudo mkdir -p /home/ubuntu/jenkins-agent
```

Перенесем `agent.jar` в `/usr/local/bin`

```bash
sudo mv agent.jar /usr/local/bin
```

Создадим файл сервиса `jenkins-agent.service`

```bash
sudo vim jenkins-agent.service
```

И внесем данные:

```bash
sudo cat /etc/systemd/system/jenkins-agent.service
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