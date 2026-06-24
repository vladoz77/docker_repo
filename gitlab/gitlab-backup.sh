#! /bin/bash
set -euo pipefail

GITLAB_DIR=./gitlab

# Check required secret environment variables
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

# Backup gitlab data 
echo "Creating GitLab backup..."
docker compose exec -T gitlab gitlab-backup create
echo "Backup configuration completed successfully. Backup files are stored in"

# Backup $GITLAB_BACKUP_DIR to s3 with restic
restic_cmd() {
  docker run --rm \
    --hostname restic-backup \
    -e RESTIC_REPOSITORY \
    -e RESTIC_PASSWORD \
    -e AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY \
    -v "$(realpath ${GITLAB_DIR}):/data:ro" \
    ghcr.io/restic/restic:latest \
    "$@"
}

echo "Initializing restic repository if it doesn't exist..." 
if ! restic_cmd snapshots > /dev/null 2>&1; then
  restic_cmd init
fi

# Backup $GITLAB_BACKUP_DIR to restic repository
echo "Backing up ${GITLAB_DIR} to restic repository..."
restic_cmd backup \
  /data/config \
  /data/backups \
  --tag gitlab-backup

# Check backup
restic_cmd ls latest

# remove old backups from restic repository
echo "Removing restic snapshots older than ..."
restic_cmd forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --prune

echo "Restic backup completed successfully."