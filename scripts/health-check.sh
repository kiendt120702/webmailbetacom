#!/bin/bash
# =============================================================
# iRedMail Health Check Script
# =============================================================
# Usage: ./health-check.sh
# Cron: */5 * * * * /path/to/health-check.sh

set -e

# Configuration
MAIL_SERVER="localhost"
ALERT_EMAIL="admin@company.local"
LOG_FILE="/var/log/iredmail-health.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Service check results
declare -A SERVICES

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] $1" | tee -a "${LOG_FILE}" 2>/dev/null || echo -e "[${timestamp}] $1"
}

check_docker_container() {
    local container=$1
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        SERVICES["${container}"]="OK"
        return 0
    else
        SERVICES["${container}"]="FAILED"
        return 1
    fi
}

check_port() {
    local port=$1
    local service=$2
    if nc -z -w5 ${MAIL_SERVER} ${port} 2>/dev/null; then
        SERVICES["${service}"]="OK"
        return 0
    else
        SERVICES["${service}"]="FAILED"
        return 1
    fi
}

check_smtp() {
    log "Checking SMTP (port 25)..."
    check_port 25 "SMTP"
}

check_submission() {
    log "Checking Submission (port 587)..."
    check_port 587 "Submission"
}

check_imap() {
    log "Checking IMAPS (port 993)..."
    check_port 993 "IMAPS"
}

check_pop3() {
    log "Checking POP3S (port 995)..."
    check_port 995 "POP3S"
}

check_https() {
    log "Checking HTTPS (port 443)..."
    if curl -sf -o /dev/null --max-time 10 "https://${MAIL_SERVER}/nginx-health" 2>/dev/null; then
        SERVICES["HTTPS"]="OK"
    elif curl -sfk -o /dev/null --max-time 10 "https://${MAIL_SERVER}/nginx-health" 2>/dev/null; then
        SERVICES["HTTPS"]="OK (self-signed)"
    else
        SERVICES["HTTPS"]="FAILED"
    fi
}

check_disk_space() {
    log "Checking disk space..."
    local usage=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "${usage}" -lt 80 ]; then
        SERVICES["Disk"]="OK (${usage}%)"
    elif [ "${usage}" -lt 90 ]; then
        SERVICES["Disk"]="WARNING (${usage}%)"
    else
        SERVICES["Disk"]="CRITICAL (${usage}%)"
    fi
}

check_memory() {
    log "Checking memory usage..."
    if command -v free &> /dev/null; then
        local usage=$(free | awk 'NR==2 {printf "%.0f", $3*100/$2}')
        if [ "${usage}" -lt 80 ]; then
            SERVICES["Memory"]="OK (${usage}%)"
        elif [ "${usage}" -lt 90 ]; then
            SERVICES["Memory"]="WARNING (${usage}%)"
        else
            SERVICES["Memory"]="CRITICAL (${usage}%)"
        fi
    else
        SERVICES["Memory"]="N/A"
    fi
}

check_mail_queue() {
    log "Checking mail queue..."
    local queue_size=$(docker exec iredmail postqueue -p 2>/dev/null | tail -n1 | grep -oP '\d+(?= Requests)' || echo "0")
    if [ "${queue_size}" -lt 100 ]; then
        SERVICES["MailQueue"]="OK (${queue_size} mails)"
    elif [ "${queue_size}" -lt 500 ]; then
        SERVICES["MailQueue"]="WARNING (${queue_size} mails)"
    else
        SERVICES["MailQueue"]="CRITICAL (${queue_size} mails)"
    fi
}

print_status() {
    echo ""
    echo "============================================="
    echo "       iRedMail Health Check Report"
    echo "       $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================="
    echo ""

    local all_ok=true

    for service in "${!SERVICES[@]}"; do
        local status="${SERVICES[$service]}"
        if [[ "$status" == "OK"* ]]; then
            echo -e "  ${GREEN}[OK]${NC}      $service: $status"
        elif [[ "$status" == "WARNING"* ]]; then
            echo -e "  ${YELLOW}[WARN]${NC}    $service: $status"
            all_ok=false
        else
            echo -e "  ${RED}[FAIL]${NC}    $service: $status"
            all_ok=false
        fi
    done

    echo ""
    echo "============================================="

    if [ "$all_ok" = true ]; then
        echo -e "  ${GREEN}All services are healthy!${NC}"
        return 0
    else
        echo -e "  ${RED}Some services need attention!${NC}"
        return 1
    fi
}

# Main execution
log "Starting health check..."

# Docker containers
check_docker_container "iredmail"
check_docker_container "nginx-proxy"

# Services
check_smtp
check_submission
check_imap
check_pop3
check_https

# System resources
check_disk_space
check_memory
check_mail_queue

# Print report
print_status
