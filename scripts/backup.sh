#!/bin/bash
# =============================================================
# iRedMail Backup Script
# =============================================================
# Usage: ./backup.sh [full|db|mail]
# Cron: 0 2 * * * /path/to/backup.sh full >> /var/log/backup.log 2>&1

set -e

# Configuration
BACKUP_DIR="/backup"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER_NAME="iredmail"

# Colors for output
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

# Create backup directory
mkdir -p "${BACKUP_DIR}"

backup_database() {
    log "Starting database backup..."

    # Backup MySQL/MariaDB
    docker exec ${CONTAINER_NAME} mysqldump \
        --all-databases \
        --single-transaction \
        --quick \
        --lock-tables=false \
        | gzip > "${BACKUP_DIR}/db_${DATE}.sql.gz"

    if [ $? -eq 0 ]; then
        log "Database backup completed: db_${DATE}.sql.gz"
    else
        error "Database backup failed!"
        return 1
    fi
}

backup_mailboxes() {
    log "Starting mailbox backup..."

    # Backup mailboxes using rsync
    MAILBOX_SOURCE="./data/mailboxes"
    MAILBOX_DEST="${BACKUP_DIR}/mailboxes_${DATE}"

    if [ -d "${MAILBOX_SOURCE}" ]; then
        mkdir -p "${MAILBOX_DEST}"
        rsync -av --delete "${MAILBOX_SOURCE}/" "${MAILBOX_DEST}/"

        # Compress the backup
        tar -czf "${BACKUP_DIR}/mailboxes_${DATE}.tar.gz" -C "${BACKUP_DIR}" "mailboxes_${DATE}"
        rm -rf "${MAILBOX_DEST}"

        log "Mailbox backup completed: mailboxes_${DATE}.tar.gz"
    else
        warn "Mailbox directory not found: ${MAILBOX_SOURCE}"
    fi
}

backup_config() {
    log "Starting configuration backup..."

    CONFIG_BACKUP="${BACKUP_DIR}/config_${DATE}"
    mkdir -p "${CONFIG_BACKUP}"

    # Backup configuration files
    cp -r ./nginx "${CONFIG_BACKUP}/" 2>/dev/null || true
    cp ./docker-compose.yml "${CONFIG_BACKUP}/" 2>/dev/null || true
    cp ./iredmail-docker.conf "${CONFIG_BACKUP}/" 2>/dev/null || true
    cp ./.env "${CONFIG_BACKUP}/" 2>/dev/null || true

    # Backup SSL certificates
    cp -r ./data/ssl "${CONFIG_BACKUP}/" 2>/dev/null || true

    tar -czf "${BACKUP_DIR}/config_${DATE}.tar.gz" -C "${BACKUP_DIR}" "config_${DATE}"
    rm -rf "${CONFIG_BACKUP}"

    log "Configuration backup completed: config_${DATE}.tar.gz"
}

cleanup_old_backups() {
    log "Cleaning up backups older than ${RETENTION_DAYS} days..."

    find "${BACKUP_DIR}" -type f -name "*.gz" -mtime +${RETENTION_DAYS} -delete
    find "${BACKUP_DIR}" -type f -name "*.sql" -mtime +${RETENTION_DAYS} -delete

    log "Cleanup completed"
}

show_backup_status() {
    log "Backup Status:"
    echo "----------------------------------------"
    du -sh "${BACKUP_DIR}"/* 2>/dev/null | sort -h
    echo "----------------------------------------"
    echo "Total backup size: $(du -sh ${BACKUP_DIR} | cut -f1)"
}

# Main execution
case "${1:-full}" in
    full)
        log "Starting FULL backup..."
        backup_database
        backup_mailboxes
        backup_config
        cleanup_old_backups
        show_backup_status
        log "FULL backup completed successfully!"
        ;;
    db)
        backup_database
        ;;
    mail)
        backup_mailboxes
        ;;
    config)
        backup_config
        ;;
    cleanup)
        cleanup_old_backups
        ;;
    status)
        show_backup_status
        ;;
    *)
        echo "Usage: $0 {full|db|mail|config|cleanup|status}"
        exit 1
        ;;
esac
