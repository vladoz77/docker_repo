#!/bin/bash
set -euo pipefail

BACKUP_DIR="./backups"

echo "=== Choose GitLab backup ==="
select GITLAB_BACKUP in "$BACKUP_DIR"/gitlab/*; do
  if [[ -n "$GITLAB_BACKUP" ]]; then
    break
  fi
  echo "Invalid selection"
done

echo "=== Choose Config backup ==="
select CONFIG_BACKUP in "$BACKUP_DIR"/gitlab-config/*; do
  if [[ -n "$CONFIG_BACKUP" ]]; then
    break
  fi
  echo "Invalid selection"
done

BACKUP_ID=$(basename "$GITLAB_BACKUP" | sed 's/_gitlab_backup\.tar$//')

echo ""
echo "GitLab backup : $GITLAB_BACKUP"
echo "Config backup : $CONFIG_BACKUP"
read -rp "Continue? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

echo "[1/3] Restoring config..."
tar -xzf "$CONFIG_BACKUP" --strip-components=1 -C ./gitlab/config/

echo "[2/3] Starting restore..."
docker compose exec -T gitlab gitlab-ctl stop puma
docker compose exec -T gitlab gitlab-ctl stop sidekiq
docker compose exec -T gitlab gitlab-backup restore BACKUP="$BACKUP_ID" force=yes

echo "[3/3] Restarting GitLab..."
docker compose exec -T gitlab gitlab-ctl reconfigure
docker compose exec -T gitlab gitlab-ctl restart

echo "Done!"