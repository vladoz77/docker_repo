#! /bin/bash
set -euo pipefail

GITLAB_BACKUP_DIR=/tmp/backups
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}

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

# Create backups directory if it doesn't exist
echo "Creating backup directories..."
mkdir -p "$GITLAB_BACKUP_DIR"/{gitlab,gitlab-config,environment}

# Backup gitlab data 
echo "Creating GitLab backup..."
docker compose exec -T gitlab gitlab-backup create
echo "Backup configuration completed successfully. Backup files are stored in"

# Move gitlab backup to backup dir
echo "Move gitlab backup to $GITLAB_BACKUP_DIR"
LATEST_GITLAB_BACKUP=$(ls -t ./gitlab/backups/*_gitlab_backup.tar 2>/dev/null | head -n1)

if [ -n $LATEST_GITLAB_BACKUP ] ;then
  cp $LATEST_GITLAB_BACKUP $GITLAB_BACKUP_DIR/gitlab
  echo "Copied: $(basename "$LATEST_GITLAB_BACKUP")"
else
  echo "Error: GitLab backup file not found!"
  exit 1
fi

# Backup gitlab configuration files
echo "Creating GitLab configuration backup..."
tar -czf "$GITLAB_BACKUP_DIR/gitlab-config/gitlab-${TIMESTAMP}.tar.gz" \
  -C ./gitlab/config \
  gitlab.rb \
  gitlab-secrets.json
echo "Backup configuration completed successfully. Backup files are stored in $GITLAB_BACKUP_DIR."

# Backup .env file
echo "Creating .env backup..."
cp .env "$GITLAB_BACKUP_DIR/environment/env-${TIMESTAMP}.backup"
echo "Backup .env completed successfully. Backup files are stored in $GITLAB_BACKUP_DIR."

# Backup $GITLAB_BACKUP_DIR to s3 with restic
restic_cmd() {
  docker run --rm \
    --hostname restic-backup \
    -e RESTIC_REPOSITORY \
    -e RESTIC_PASSWORD \
    -e AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY \
    -v "$(realpath ${GITLAB_BACKUP_DIR}):/data:ro" \
    ghcr.io/restic/restic:latest \
    "$@"
}

echo "Initializing restic repository if it doesn't exist..." 
if ! restic_cmd snapshots > /dev/null 2>&1; then
  restic_cmd init
fi

# Backup $GITLAB_BACKUP_DIR to restic repository
echo "Backing up $GITLAB_BACKUP_DIR to restic repository..."
restic_cmd backup \
  /data/gitlab \
  /data/gitlab-config \
  /data/environment \
  --tag gitlab-backup

# remove old backups from restic repository
echo "Removing restic snapshots older than $BACKUP_RETENTION_DAYS days..."
restic_cmd forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --prune

echo "Restic backup completed successfully."

# Remove backups older than BACKUP_RETENTION_DAYS
echo "Applying restic retention policy..."
find "$GITLAB_BACKUP_DIR" -type f -mtime +"$BACKUP_RETENTION_DAYS" -exec rm -f {} \;