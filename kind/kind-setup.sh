#!/usr/bin/env bash

set -euo pipefail

KIND_CLUSTER_NAME='local-kind'
REGISTRIES=(
  "docker-registry"
  "quay-registry"
  "ghcr-registry"
)

echo "Check kind cluster"
if ! kind get clusters | grep -qw "${KIND_CLUSTER_NAME}"; then
  echo "Create kind cluster ${KIND_CLUSTER_NAME}..."
  kind create cluster --name="${KIND_CLUSTER_NAME}" --config=kind-config.yaml
else
  echo "Kind cluster ${KIND_CLUSTER_NAME} already exist..."
fi

echo "Add local registries to kind"
for registry in "${REGISTRIES[@]}"; do
  echo "Add ${registry} to kind network"
  docker network connect kind "${registry}" >/dev/null 2>&1 || true
  echo "done"
done

echo "Argocd installing..."
if ! helm list --all-namespaces | grep -qw "argocd"; then
  echo "Installing agrocd via Helm"
  helm repo add argo https://argoproj.github.io/argo-helm
  helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace -f argocd-bootstrap.yaml
else
  echo "Argocd have already installed"
fi

echo "Install complete"
