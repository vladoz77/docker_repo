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
