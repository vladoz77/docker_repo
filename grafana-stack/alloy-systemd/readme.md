# Install Alloy Binary and Start as a Service

## Install alloy

Now we will create the Alloy agent service that will act as the collector for Loki.

We can also get the Alloy binary from github.

To check the latest version of Alloy, visit its https://github.com/grafana/alloy/releases.

```bash
sudo apt install unzip -y
curl -O -L "https://github.com/grafana/alloy/releases/download/v1.10.2/alloy-linux-amd64.zip"
unzip "alloy-linux-amd64.zip"
sudo install alloy-linux-amd64 /usr/local/bin/alloy
```

## Create user alloy

Create user specifically for the Alloy service and add groups

```bash
sudo useradd --system alloy
sudo usermod -aG adm alloy
sudo usermod -aG systemd-journal alloy
sudo usermod -aG docker alloy
```

Verify that the user is now in the groups

```bash
sudo groups alloy
```

## Config alloy service

Create folder for config alloy

```bash
sudo mkdir -p /etc/alloy
sudo mv config.alloy /etc/alloy/
```

Copy alloy.service to `/etc/systemd/system/`

```bash
sudo mv alloy.service  /etc/systemd/system/
```

Restart Alloy and check status

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now alloy.service
sudo systemctl status alloy.service
sudo journalctl -u alloy.service -f
```
