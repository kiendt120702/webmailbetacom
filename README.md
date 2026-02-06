# iRedMail Webmail Server

Mail server noi bo cong ty su dung iRedMail Docker.

## Yeu Cau He Thong

| Thong so | Toi thieu | Khuyen nghi |
|----------|-----------|-------------|
| RAM | 8 GB | 16 GB |
| CPU | 4 cores | 8 cores |
| Storage | 500 GB SSD | 1-2 TB SSD |
| Docker | 20.10+ | Latest |
| Docker Compose | 2.0+ | Latest |

## Cai Dat Nhanh

### 1. Cau Hinh

```bash
# Chinh sua file cau hinh
nano iredmail-docker.conf

# Thay doi cac gia tri:
# - HOSTNAME=mail.company.com
# - FIRST_MAIL_DOMAIN=company.com
# - FIRST_MAIL_DOMAIN_ADMIN_PASSWORD=MatKhauManh123!

# Generate tokens
openssl rand -base64 32  # -> MLMMJADMIN_API_TOKEN
openssl rand -base64 24  # -> ROUNDCUBE_DES_KEY
```

### 2. Tao SSL Certificate

```bash
cd scripts
chmod +x *.sh
./generate-ssl.sh mail.company.com
```

### 3. Khoi Dong

```bash
# Khoi dong tat ca services
docker-compose up -d

# Xem logs
docker-compose logs -f

# Doi khoang 2-3 phut de services khoi dong hoan tat
```

### 4. Truy Cap

| Service | URL | Ghi chu |
|---------|-----|---------|
| Webmail (Roundcube) | https://mail.company.com | Nguoi dung |
| Admin Panel | https://mail.company.com/iredadmin | Quan tri |
| SOGo (Calendar) | https://mail.company.com/SOGo | Neu bat |

**Tai khoan admin mac dinh:**
- Email: `postmaster@company.com`
- Mat khau: Gia tri cua `FIRST_MAIL_DOMAIN_ADMIN_PASSWORD`

## Quan Tri

### Tao User Moi

1. Truy cap iRedAdmin: https://mail.company.com/iredadmin
2. Dang nhap bang tai khoan postmaster
3. Add -> User -> Dien thong tin

### Backup

```bash
# Backup toan bo
./scripts/backup.sh full

# Chi backup database
./scripts/backup.sh db

# Chi backup mailbox
./scripts/backup.sh mail

# Xem trang thai backup
./scripts/backup.sh status
```

### Restore

```bash
# Liet ke cac backup co san
./scripts/restore.sh

# Restore tu backup cu the
./scripts/restore.sh 20240115_020000
```

### Health Check

```bash
./scripts/health-check.sh
```

### Cac Lenh Docker Huu Ich

```bash
# Xem trang thai containers
docker-compose ps

# Xem logs realtime
docker-compose logs -f iredmail

# Restart services
docker-compose restart

# Dung tat ca
docker-compose down

# Xem mail queue
docker exec iredmail postqueue -p

# Flush mail queue
docker exec iredmail postqueue -f
```

## Ports

| Port | Service | Mo ta |
|------|---------|-------|
| 25 | SMTP | Nhan mail tu external |
| 80 | HTTP | Redirect to HTTPS |
| 443 | HTTPS | Webmail |
| 587 | Submission | Gui mail (STARTTLS) |
| 993 | IMAPS | IMAP over SSL |
| 995 | POP3S | POP3 over SSL |

## Cau Hinh Email Client

### Thunderbird / Outlook

**Incoming (IMAP):**
- Server: mail.company.com
- Port: 993
- Security: SSL/TLS
- Username: email@company.com

**Outgoing (SMTP):**
- Server: mail.company.com
- Port: 587
- Security: STARTTLS
- Username: email@company.com

## Xu Ly Su Co

### Container khong khoi dong
```bash
docker-compose logs iredmail
```

### Khong gui/nhan duoc mail
```bash
# Kiem tra mail queue
docker exec iredmail postqueue -p

# Xem log mail
docker exec iredmail tail -f /var/log/mail.log
```

### Quen mat khau admin
```bash
# Reset password trong database
docker exec -it iredmail mysql vmail
> UPDATE mailbox SET password=ENCRYPT('NewPassword123!') WHERE username='postmaster@company.com';
```

## Bao Mat

1. **Doi mat khau admin** ngay sau khi cai dat
2. **Backup thuong xuyen** - Thiet lap cron job
3. **Update thuong xuyen** - `docker-compose pull && docker-compose up -d`
4. **Firewall** - Chi mo cac port can thiet
5. **SSL** - Su dung Let's Encrypt cho production

## Tac Gia

IT Department - BetacomCoding
