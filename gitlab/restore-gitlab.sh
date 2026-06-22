#!/bin/bash
set -euo pipefail

set -a        
source .env   
set +a  

RESTORE_DIR="./restore"

# Create restore directory if it doesn't exist
echo "Creating restore directory..."
mkdir -p "$RESTORE_DIR"

# Restore $RESTORE_DIR from s3 with restic
restic_cmd() {
  docker run --rm \
    --hostname restic-backup \
    --env-file .env \
    -v "$(realpath ${RESTORE_DIR}):/data" \
    ghcr.io/restic/restic:latest \
    "$@"
}

restic_cmd restore latest --target /data --tag gitlab-backup

echo "=== Choose GitLab backup ==="
select GITLAB_BACKUP in "$RESTORE_DIR"/data/gitlab/*; do
  if [[ -n "$GITLAB_BACKUP" ]]; then
    break
  fi
  echo "Invalid selection"
done

echo "=== Choose Config backup ==="
select CONFIG_BACKUP in "$RESTORE_DIR"/data/gitlab-config/*; do
  if [[ -n "$CONFIG_BACKUP" ]]; then
    break
  fi
  echo "Invalid selection"
done

echo "=== Choose environment backup ==="
select ENV_BACKUP in "$RESTORE_DIR"/data/environment/*; do
  if [[ -n "$ENV_BACKUP" ]]; then
    break
  fi
  echo "Invalid selection"
done


BACKUP_ID=$(basename "$GITLAB_BACKUP" | sed 's/_gitlab_backup\.tar$//')

echo ""
echo "GitLab backup : $GITLAB_BACKUP"
echo "Config backup : $CONFIG_BACKUP"
echo "Environment backup : $ENV_BACKUP"
read -rp "Continue? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

echo "Restoring config..."
tar -xzf "$CONFIG_BACKUP" --strip-components=1 -C ./gitlab/config/

echo "Restoring environment variables..."
cp "$ENV_BACKUP" .env

echo "GitLab restore..."
docker compose exec -T gitlab gitlab-ctl stop puma
docker compose exec -T gitlab gitlab-ctl stop sidekiq
docker compose exec -T gitlab gitlab-backup restore BACKUP="$BACKUP_ID" force=yes

echo "Restarting GitLab..."
docker compose exec -T gitlab gitlab-ctl reconfigure
docker compose exec -T gitlab gitlab-ctl restart

echo "Done!"