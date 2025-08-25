## Установка Jenkins в docker-compose

1. Установка docker и docker-compose

1.1 Установим репозитарии докер:

```bash
# Add Docker's official GPG key:
sudo apt-get update -y
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
```

1.2 Установим необходимые пакеты

```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```
1.3 Настроим права

```bash
sudo usermod -aG docker ${USER}
```

2.0 Установка Jenkins и traefik

```bash
docker compose up -d
```

Проверка логов

```bash
docker logs jenkins
```

3.0 Заходим на страницу `https://jenkins.yc.home-local.site/`

