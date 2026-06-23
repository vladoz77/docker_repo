  #!/bin/bash
  set -euo pipefail

  RESTORE_DIR="/tmp/restore"
  GITLAB_DIR="./gitlab"

  # Check required environment variables
  required_vars=(
    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    RESTIC_PASSWORD
    RESTIC_REPOSITORY
  )

  # Check required environment variables
  echo "Checking required environment variables..."
  for var in "${required_vars[@]}"; do
    if [[ ! -v $var ]]; then
      echo "Missing required variable: $var"
      exit 1
    fi
  done
  echo "All required variables are set"


  # Clean restore dir
  echo "Cleaning $RESTORE_DIR"
  rm -rf $RESTORE_DIR/*

  # Create restore directory if it doesn't exist
  echo "Creating restore directory..."
  mkdir -p "$RESTORE_DIR"/{gitlab,gitlab-config}

  # Restore $RESTORE_DIR from s3 with restic
  restic_cmd() {
    docker run --rm \
      --hostname restic-backup \
      -e RESTIC_REPOSITORY \
      -e RESTIC_PASSWORD \
      -e AWS_ACCESS_KEY_ID \
      -e AWS_SECRET_ACCESS_KEY \
      -v "$(realpath ${RESTORE_DIR}):/data" \
      ghcr.io/restic/restic:latest \
      "$@"
  }

  restic_cmd restore latest --target /data --tag gitlab-backup
  
  GITLAB_BACKUP=$(ls -t "$RESTORE_DIR/data/gitlab"/*_gitlab_backup.tar | head -n1)
  BACKUP_ID=$(basename "$GITLAB_BACKUP" | sed 's/_gitlab_backup\.tar$//')
  CONFIG_BACKUP=$(ls -t "$RESTORE_DIR/data/gitlab-config"/*.tar.gz | head -n1)

  echo ""
  echo "GitLab backup : $GITLAB_BACKUP"
  echo "Config backup : $CONFIG_BACKUP"
  read -rp "Continue? [y/N]: " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

  echo "Restoring config..."
  tar -xzf "$CONFIG_BACKUP"  -C "${GITLAB_DIR}"/config
  echo "done"

  echo "Moving GitLab backup to volume..."
  mv "$GITLAB_BACKUP" "$GITLAB_DIR"/backups
  
  echo "Fix permission"
  chown 998:998 "$GITLAB_DIR"/backups/*.tar
  chmod 644 "$GITLAB_DIR"/backups/*.tar

  echo "Starting GitLab restore..."
  docker compose exec -T gitlab gitlab-ctl stop puma
  docker compose exec -T gitlab gitlab-ctl stop sidekiq
  docker compose exec -T gitlab gitlab-backup restore BACKUP="$BACKUP_ID" force=yes

  echo "Restarting GitLab..."
  docker compose exec -T gitlab gitlab-ctl reconfigure
  docker compose exec -T gitlab gitlab-ctl restart
  echo "Done!"