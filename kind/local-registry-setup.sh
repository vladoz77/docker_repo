#!/usr/bin/bash
KIND_CLUSTER_NAME='local-kind'
REGISTRY_NAME='local-registry'
REGISTRY_NETWORK='local-registry'


# Add registry container to the kind docker network.
docker network connect kind "${REGISTRY_NAME}" 2>/dev/null || true

for node in $(kind get nodes --name="${KIND_CLUSTER_NAME}"); do
  # Create the certs.d directory if it doesn't exist
  echo "Configuring ${node} to use the local registry mirror at ${REGISTRY_NAME}:5000"
  docker exec "${node}" mkdir -p /etc/containerd/certs.d/docker.io
  cat <<EOF | docker exec -i "${node}" tee /etc/containerd/certs.d/docker.io/hosts.toml >/dev/null
server = "https://registry-1.docker.io"

[host."http://${REGISTRY_NAME}:5000"]
  capabilities = ["pull", "resolve"]
EOF
  echo "Configuring ${node} is complete."

done
