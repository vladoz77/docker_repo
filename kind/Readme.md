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
- [Helm](https://helm.sh/docs/intro/install/)

Проверить установку можно так:

```bash
docker --version
kubectl version --client
kind --version
helm version
```

## Установка kind

### Linux

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Установка kubectl

Если `kubectl` ещё не установлен, можно поставить его по официальной инструкции:

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Установка Helm

Если `helm` ещё не установлен:

#### Linux

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
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

## Envoy Gateway + HTTPS с самоподписанным CA

### Установите Envoy Gateway controller

Helm chart Envoy Gateway поднимает controller и необходимые CRD для `Gateway API`.

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.2 \
  -n envoy-gateway-system \
  --create-namespace
EOF
```

Проверка:

```bash
kubectl get gatewayclass
kubectl get pods -n envoy-gateway-system
```

### Установите cert-manager с поддержкой Gateway API

```bash
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.20.2 \
  --set crds.enabled=true \
  --set config.enableGatewayAPI=true
```

Проверка:

```bash
kubectl get pods -n cert-manager
kubectl wait --for=condition=Available deployment \
  -n cert-manager \
  --all \
  --timeout=5m
```

Примечание: если `cert-manager` был установлен до появления CRD `Gateway API`, после их установки перезапустите controller:

```bash
kubectl rollout restart deployment cert-manager -n cert-manager
```

### Установите trust-manager

`trust-manager` будет автоматически собирать CA bundle и раскладывать его по `ConfigMap` в кластере.

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade trust-manager jetstack/trust-manager \
  --install \
  --namespace cert-manager 
```

Проверка:

```bash
kubectl get pods -n cert-manager
kubectl get crd bundles.trust.cert-manager.io
```

### Создайте self-signed CA, ClusterIssuer и trust bundle

Ниже создаются:

- `selfsigned-issuer` для bootstrap корневого сертификата
- `ca` и `ca-secret` в namespace `cert-manager`
- `ca-issuer` для выпуска leaf-сертификатов
- `Bundle` `trust-ca` для распространения CA bundle по кластеру

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}

---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ca
  namespace: cert-manager
spec:
  isCA: true
  subject:
    organizations:
      - "Vlad's homelab"
    organizationalUnits:
      - "Home lab"
    localities:
      - "Ryazan"
    countries:
      - "RU"
  commonName: ca
  secretName: ca-secret
  privateKey:
    encoding: PKCS8
    algorithm: RSA
    size: 4096
    rotationPolicy: Always
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
    group: cert-manager.io

---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-secret

---
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: trust-ca
spec:
  sources:
  - secret:
      name: ca-secret
      key: tls.crt
  target:
    configMap:
      key: trust-bundle.pem
EOF
```

Проверка bootstrap CA:

```bash
kubectl get clusterissuer selfsigned-issuer ca-issuer
kubectl wait --for=condition=Ready certificate/ca -n cert-manager --timeout=5m
kubectl get certificate ca -n cert-manager
kubectl get secret ca-secret -n cert-manager
kubectl describe certificate ca -n cert-manager
kubectl get bundle trust-ca
kubectl describe bundle trust-ca
```

Примечание: в текущих версиях `trust-manager` пустой `namespaceSelector` у `Bundle` означает распространение target `ConfigMap` во все namespace кластера.

### Создайте Gateway с listeners HTTP и HTTPS

`cert-manager` создаст `Certificate` и TLS secret автоматически по аннотации `cert-manager.io/cluster-issuer: ca-issuer`. Для `Envoy Gateway`, установленного chart-ом выше, по умолчанию используется `GatewayClass` с именем `eg`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-gateway
  namespace: envoy-gateway-system
  annotations:
    cert-manager.io/cluster-issuer: ca-issuer
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "*.dev.local"
    allowedRoutes:
      namespaces:
        from: All
    tls:
      mode: Terminate
      certificateRefs:
      - name: envoy-tls-secret
EOF
```

Проверка:

```bash
kubectl get gateway -n envoy-gateway-system
kubectl describe gateway envoy-gateway -n envoy-gateway-system
kubectl get certificate -n envoy-gateway-system
kubectl get secret envoy-tls-secret -n envoy-gateway-system
```

Этот вариант:

- создаёт `Gateway` `envoy-gateway`
- поднимает listeners `http` и `https`
- использует `ClusterIssuer` `ca-issuer`
- выпускает TLS secret `envoy-tls-secret` автоматически

Важно:

- для автоматического выпуска сертификата у `HTTPS` listener обязательно должны быть `hostname`, `tls.mode: Terminate` и `certificateRefs`
- `HTTPRoute`, которые должны публиковаться через этот gateway, должны ссылаться на `Gateway` с именем `envoy-gateway`
- wildcard `*.dev.local` покрывает хосты вида `app.dev.local`, но не сам `dev.local`


### Получите адрес Gateway

```bash
kubectl get gateway envoy-gateway -n envoy-gateway-system \
  -o jsonpath='{.status.addresses[0].value}'
echo
```

Если вы используете `*.dev.local`, добавьте в `/etc/hosts` конкретный hostname, который будете открывать, например:

```text
172.18.255.201 app.dev.local
```

Здесь `172.18.255.201` нужно заменить на реальный адрес из статуса `Gateway` или `EXTERNAL-IP` сервиса Envoy.

Если у локального кластера нет внешнего адреса, посмотрите сервисы Envoy Gateway:

```bash
kubectl get svc -n envoy-gateway-system
```

И используйте `port-forward` к сервису data plane. Имя сервиса можно получить так:

```bash
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=envoy-gateway-system,gateway.envoyproxy.io/owning-gateway-name=envoy-gateway \
  -o jsonpath='{.items[0].metadata.name}')

kubectl -n envoy-gateway-system port-forward service/${ENVOY_SERVICE} 8080:80 8443:443
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
