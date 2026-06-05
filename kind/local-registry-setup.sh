#!/usr/bin/env bash

set -euo pipefail

KIND_CLUSTER_NAME='local-kind'
REGISTRY_NAME='local-registry'

echo "=== Проверка и создание Kind кластера ==="
if ! kind get clusters | grep -qw "${KIND_CLUSTER_NAME}"; then
  echo "Создание kind кластера ${KIND_CLUSTER_NAME}..."
  kind create cluster --name="${KIND_CLUSTER_NAME}" --config=kind-config.yaml
else
  echo "Kind кластер ${KIND_CLUSTER_NAME} уже существует. Пропускаем создание."
fi

echo "=== Подключение локального реестра к сети Docker ==="
docker network connect kind "${REGISTRY_NAME}" >/dev/null 2>&1 || true

echo "=== Установка ArgoCD ==="
if ! helm list --all-namespaces | grep -qw "argocd"; then
  echo "Установка ArgoCD через Helm..."
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace -f argocd-bootstrap.yaml
else
  echo "ArgoCD уже установлен. Пропускаем Helm bootstrap."
fi

echo "=== Все шаги успешно выполнены! ==="