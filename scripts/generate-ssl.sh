#!/bin/bash
# =============================================================
# Generate Self-Signed SSL Certificate for iRedMail
# =============================================================
# Usage: ./generate-ssl.sh [domain]
# Example: ./generate-ssl.sh mail.company.local

set -e

DOMAIN="${1:-mail.company.local}"
SSL_DIR="../nginx/ssl"
DAYS_VALID=3650  # 10 years for internal use

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[SSL]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Create SSL directory
mkdir -p "${SSL_DIR}"

log "Generating self-signed SSL certificate for: ${DOMAIN}"

# Generate private key and certificate
openssl req -x509 \
    -nodes \
    -days ${DAYS_VALID} \
    -newkey rsa:4096 \
    -keyout "${SSL_DIR}/server.key" \
    -out "${SSL_DIR}/server.crt" \
    -subj "/C=VN/ST=HCM/L=Ho Chi Minh/O=Company/OU=IT/CN=${DOMAIN}" \
    -addext "subjectAltName=DNS:${DOMAIN},DNS:localhost,IP:127.0.0.1"

# Set permissions
chmod 600 "${SSL_DIR}/server.key"
chmod 644 "${SSL_DIR}/server.crt"

log "SSL certificate generated successfully!"
echo ""
echo "Certificate: ${SSL_DIR}/server.crt"
echo "Private Key: ${SSL_DIR}/server.key"
echo "Valid for: ${DAYS_VALID} days"
echo ""
warn "For production, consider using Let's Encrypt or a trusted CA."
