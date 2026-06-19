#!/bin/bash
set -euo pipefail
set -a
source .env
set +a

BACKUP_DIR="./backups"

echo "=== Choose GitLab backup ==="
select GITLAB_BACKUP in "$BACKUP_DIR"/gitlab/*; do
  [[ -n "$GITLAB_BACKUP" ]] && break
  echo "Invalid selection"
done

echo ""
echo "=== Choose Config backup ==="
select CONFIG_BACKUP in "$BACKUP_DIR"/gitlab-config/*; do
  [[ -n "$CONFIG_BACKUP" ]] && break
  echo "Invalid selection"
done

BACKUP_ID=$(basename "$GITLAB_BACKUP" | sed 's/_gitlab_backup\.tar$//')

echo ""
echo "GitLab backup : $GITLAB_BACKUP"
echo "Config backup : $CONFIG_BACKUP"
read -rp "Continue? [y/N]: " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

echo "[1/3] Восстанавливаем конфиг..."
tar -xzf "$CONFIG_BACKUP" --strip-components=1 -C ./gitlab/config/

echo "[2/3] Запускаем restore..."
docker compose exec -T gitlab gitlab-ctl stop puma
docker compose exec -T gitlab gitlab-ctl stop sidekiq
docker compose exec -T gitlab gitlab-backup restore BACKUP="$BACKUP_ID" force=yes

echo "[3/3] Перезапускаем GitLab..."
docker compose exec -T gitlab gitlab-ctl reconfigure
docker compose exec -T gitlab gitlab-ctl restart

echo "Готово!"