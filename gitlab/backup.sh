#! /bin/bash
set -euo pipefail
set -a        
source .env   
set +a  

TIMESTAMP="$(date +%F_%H-%M)"
BACKUP_DIR="./backups"
BACKUP_RETENTION_DAYS=7

# Create backups directory if it doesn't exist
echo "Creating backup directories..."
mkdir -p $BACKUP_DIR/{gitlab,gitlab-config,postgres,traefik}

# Backup gitlab data 
echo "Creating GitLab backup..."
docker compose exec -T gitlab gitlab-backup create

# Backup gitlab configuration files
echo "Creating GitLab configuration backup..."
tar -czf "$BACKUP_DIR/gitlab-config/gitlab-${TIMESTAMP}.tar.gz" \
  ./gitlab/config/gitlab.rb \
  ./gitlab/config/gitlab-secrets.json

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

# Remove backups older than BACKUP_RETENTION_DAYS
echo "Removing backups older than $BACKUP_RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -mtime +"$BACKUP_RETENTION_DAYS" -exec rm -f {} \;

echo "Backup completed successfully. Backup files are stored in $BACKUP_DIR."