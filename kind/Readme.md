# Kind Cluster: 1 control-plane + 3 worker nodes

Этот репозиторий содержит конфигурацию локального Kubernetes-кластера на базе [kind](https://kind.sigs.k8s.io/) с:

- 1 `control-plane` нодой
- 3 `worker` нодами

Файл конфигурации кластера: [kind-config.yaml](/home/vlad/docker_repo/kind/kind-config.yaml)

## Состав кластера

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
```

Примечание: в современных версиях Kubernetes и `kind` вместо термина `master` используется `control-plane`.

## Требования

Перед началом убедитесь, что установлены:

- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/)

Проверить установку можно так:

```bash
docker --version
kubectl version --client
kind --version
```

## Установка kind

### Linux

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### macOS

Если установлен Homebrew:

```bash
brew install kind
```

### Установка kubectl

Если `kubectl` ещё не установлен, можно поставить его по официальной инструкции:

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

## Создание кластера

Перейдите в директорию проекта:

```bash
cd /home/vlad/docker_repo/kind
```

Создайте кластер по конфигу:

```bash
kind create cluster --name local-kind --config kind-config.yaml
```

## Настройка MetalLB для kind

`kind` не выдаёт внешние IP для сервисов типа `LoadBalancer` "из коробки", поэтому для локальной разработки удобно добавить [MetalLB](https://metallb.io/).

Важно: проброс портов `80/443` в [kind-config.yaml](/home/vlad/docker_repo/kind/kind-config.yaml) не заменяет MetalLB. Эти настройки полезны для `Ingress` или `NodePort`, а MetalLB нужен именно для сервисов с `type: LoadBalancer`.

### 1. Установите MetalLB

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml
```

Примечание: для стандартного `kind` с `kube-proxy` в режиме `iptables` дополнительная настройка `strictARP` обычно не требуется. Если вы вручную переключали `kube-proxy` в режим `ipvs`, включите `strictARP: true` по официальной инструкции MetalLB.

### 2. Определите диапазон IP для сервисов

Посмотрите подсеть Docker-сети `kind`:

```bash
docker network inspect kind -f '{{(index .IPAM.Config 0).Subnet}}'
```

Обычно это что-то вроде `172.18.0.0/16`. Выберите свободный диапазон внутри этой сети, который не используется контейнерами. Ниже пример для диапазона `172.18.255.200-172.18.255.250`.

### 3. Создайте конфигурацию MetalLB

Примените конфигурацию через heredoc:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
    - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: metallb-system
EOF
```

Проверьте, что ресурсы создались:

```bash
kubectl get ipaddresspools -n metallb-system
kubectl get l2advertisements -n metallb-system
```

### 4. Проверьте выдачу внешнего IP

Создайте тестовый сервис:

```bash
kubectl create deployment demo --image=nginx
kubectl expose deployment demo --port 80 --type LoadBalancer
kubectl get svc demo -w
```

Когда у сервиса появится `EXTERNAL-IP`, проверьте доступ:

```bash
curl http://EXTERNAL-IP
```

Для очистки тестовых ресурсов:

```bash
kubectl delete svc demo
kubectl delete deployment demo
```

## Проверка кластера

Проверить, что кластер создан:

```bash
kind get clusters
```

Проверить ноды:

```bash
kubectl get nodes
```

Ожидаемый результат: 4 ноды, из них:

- 1 `control-plane`
- 3 `worker`

Посмотреть подробную информацию:

```bash
kubectl cluster-info
kubectl get pods -A
```

## Полезные команды

Просмотр контекста:

```bash
kubectl config current-context
kubectl config get-contexts
```

Просмотр всех ресурсов:

```bash
kubectl get all -A
```

Описание ноды:

```bash
kubectl describe node local-kind-worker
```

## Удаление кластера

Когда кластер больше не нужен:

```bash
kind delete cluster --name local-kind
```
