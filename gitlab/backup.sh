#! /bin/bash
set -euo pipefail
set -a        
source .env   
set +a  

# Create backups directory if it doesn't exist
echo "Creating backup directories..."
mkdir -p $BACKUP_DIR/{gitlab,gitlab-config,postgres,traefik,environment}

# Backup gitlab data 
echo "Creating GitLab backup..."
docker compose exec -T gitlab gitlab-backup create

# Backup gitlab configuration files
echo "Creating GitLab configuration backup..."
tar -czf "$BACKUP_DIR/gitlab-config/gitlab-${TIMESTAMP}.tar.gz" \
  ./gitlab/config/gitlab.rb \
  ./gitlab/config/gitlab-secrets.json

# Backup .env file
echo "Creating .env backup..."
cp .env "$BACKUP_DIR/environment/env-${TIMESTAMP}.backup"

# Backup postgres database
echo "Creating PostgreSQL backup..."
docker compose exec -T postgres pg_dump \
  -U "$DB_USERNAME" \
  -d "$DB_NAME" \
  -Fc \
  > "$BACKUP_DIR/postgres/gitlab-db-${TIMESTAMP}.dump"

# Backup traefik configuration files
echo "Creating Traefik configuration backup..."
tar -czf "$BACKUP_DIR/traefik/traefik-${TIMESTAMP}.tar.gz" \
  ./traefik/traefik.yml \
  ./traefik/acme.json

echo "Backup completed successfully. Backup files are stored in $BACKUP_DIR."

# Backup $BACKUP_DIR to s3 with restic
restic_cmd() {
  docker run --rm \
    --hostname restic-backup \
    --env-file .env \
    -v "$(realpath ${BACKUP_DIR}):/data:ro" \
    ghcr.io/restic/restic:latest \
    "$@"
}

echo "Initializing restic repository if it doesn't exist..." 
if ! restic_cmd snapshots > /dev/null 2>&1; then
  restic_cmd init
fi

# Backup $BACKUP_DIR to restic repository
echo "Backing up $BACKUP_DIR to restic repository..."
restic_cmd backup /data --tag gitlab-backup

# remove old backups from restic repository
echo "Removing restic snapshots older than $BACKUP_RETENTION_DAYS days..."
restic_cmd forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --prune

echo "Restic backup completed successfully."

# Remove backups older than BACKUP_RETENTION_DAYS
echo "Removing backups older than $BACKUP_RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -mtime +"$BACKUP_RETENTION_DAYS" -exec rm -f {} \;

