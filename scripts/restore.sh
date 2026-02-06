#!/bin/bash
# =============================================================
# iRedMail Restore Script
# =============================================================
# Usage: ./restore.sh <backup_date>
# Example: ./restore.sh 20240115_020000

set -e

# Configuration
BACKUP_DIR="/backup"
CONTAINER_NAME="iredmail"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

if [ -z "$1" ]; then
    echo "Usage: $0 <backup_date>"
    echo ""
    echo "Available backups:"
    ls -la "${BACKUP_DIR}"/*.gz 2>/dev/null | awk '{print $NF}' | xargs -I {} basename {} | sort
    exit 1
fi

BACKUP_DATE=$1

restore_database() {
    local db_backup="${BACKUP_DIR}/db_${BACKUP_DATE}.sql.gz"

    if [ ! -f "${db_backup}" ]; then
        error "Database backup not found: ${db_backup}"
        return 1
    fi

    log "Restoring database from ${db_backup}..."
    warn "This will OVERWRITE current database. Continue? (y/N)"
    read -r confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log "Database restore cancelled."
        return 0
    fi

    # Stop services that use the database
    log "Stopping mail services..."
    docker exec ${CONTAINER_NAME} service postfix stop || true
    docker exec ${CONTAINER_NAME} service dovecot stop || true

    # Restore database
    gunzip -c "${db_backup}" | docker exec -i ${CONTAINER_NAME} mysql

    # Restart services
    log "Starting mail services..."
    docker exec ${CONTAINER_NAME} service postfix start
    docker exec ${CONTAINER_NAME} service dovecot start

    log "Database restore completed!"
}

restore_mailboxes() {
    local mail_backup="${BACKUP_DIR}/mailboxes_${BACKUP_DATE}.tar.gz"

    if [ ! -f "${mail_backup}" ]; then
        error "Mailbox backup not found: ${mail_backup}"
        return 1
    fi

    log "Restoring mailboxes from ${mail_backup}..."
    warn "This will OVERWRITE current mailboxes. Continue? (y/N)"
    read -r confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log "Mailbox restore cancelled."
        return 0
    fi

    # Extract to temporary directory
    TEMP_DIR=$(mktemp -d)
    tar -xzf "${mail_backup}" -C "${TEMP_DIR}"

    # Sync mailboxes
    rsync -av --delete "${TEMP_DIR}/mailboxes_${BACKUP_DATE}/" "./data/mailboxes/"

    # Cleanup
    rm -rf "${TEMP_DIR}"

    # Fix permissions
    docker exec ${CONTAINER_NAME} chown -R vmail:vmail /var/vmail/vmail1

    log "Mailbox restore completed!"
}

restore_config() {
    local config_backup="${BACKUP_DIR}/config_${BACKUP_DATE}.tar.gz"

    if [ ! -f "${config_backup}" ]; then
        error "Config backup not found: ${config_backup}"
        return 1
    fi

    log "Restoring configuration from ${config_backup}..."
    warn "This will OVERWRITE current configuration. Continue? (y/N)"
    read -r confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log "Config restore cancelled."
        return 0
    fi

    # Extract to temporary directory
    TEMP_DIR=$(mktemp -d)
    tar -xzf "${config_backup}" -C "${TEMP_DIR}"

    # Copy config files
    cp "${TEMP_DIR}/config_${BACKUP_DATE}/docker-compose.yml" ./ 2>/dev/null || true
    cp "${TEMP_DIR}/config_${BACKUP_DATE}/iredmail-docker.conf" ./ 2>/dev/null || true
    cp -r "${TEMP_DIR}/config_${BACKUP_DATE}/nginx" ./ 2>/dev/null || true

    # Cleanup
    rm -rf "${TEMP_DIR}"

    log "Configuration restore completed!"
    warn "Please restart containers to apply changes: docker-compose restart"
}

# Main execution
case "${2:-all}" in
    all)
        log "Starting FULL restore for ${BACKUP_DATE}..."
        restore_database
        restore_mailboxes
        restore_config
        log "FULL restore completed!"
        warn "Please restart containers: docker-compose down && docker-compose up -d"
        ;;
    db)
        restore_database
        ;;
    mail)
        restore_mailboxes
        ;;
    config)
        restore_config
        ;;
    *)
        echo "Usage: $0 <backup_date> [all|db|mail|config]"
        exit 1
        ;;
esac
