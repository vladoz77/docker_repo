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
  mkdir -p "$RESTORE_DIR"

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

  restic_cmd snapshots
  read -rp "Enter Snapshot ID [latest]: " SNAPSHOT_ID
  SNAPSHOT_ID=${SNAPSHOT_ID:-latest}

  restic_cmd restore "$SNAPSHOT_ID" --target /data
  
  GITLAB_BACKUP=$(ls -t "$RESTORE_DIR/data/backups"/*_gitlab_backup.tar | head -n1)
  BACKUP_ID=$(basename "$GITLAB_BACKUP" | sed 's/_gitlab_backup\.tar$//')

  echo "Copy gitlab config to ${GITLAB_DIR}"
  cp -a "$RESTORE_DIR/data/config/." "${GITLAB_DIR}/config/"
  echo "done"

  echo "Copy gitlab backup to ${GITLAB_DIR} and fix permissions" 
  cp -a "$RESTORE_DIR/data/backups/." "$GITLAB_DIR/backups/"
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