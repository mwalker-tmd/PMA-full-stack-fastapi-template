# Deployment Checklist

Use this checklist to ensure you've completed all necessary steps before deploying to production.

## Table of Contents

- [Pre-Deployment](#pre-deployment)
- [Server Setup](#server-setup)
- [Environment Configuration](#environment-configuration)
- [Database Setup](#database-setup)
- [Application Deployment](#application-deployment)
- [Post-Deployment](#post-deployment)
- [Security Hardening](#security-hardening)
- [Monitoring & Maintenance](#monitoring--maintenance)

---

## Pre-Deployment

### Code & Testing

- [ ] All tests passing locally
  ```bash
  docker compose exec backend bash /app/scripts/test.sh
  docker compose run --rm playwright npx playwright test
  ```
- [ ] No lint errors
  ```bash
  cd backend && uv run prek run --all-files
  ```
- [ ] Code reviewed and approved
- [ ] Git branch is clean (no uncommitted changes)
- [ ] Version/tag created for this release
  ```bash
  git tag -a v1.0.0 -m "Release version 1.0.0"
  git push origin v1.0.0
  ```

### Documentation

- [ ] README.md updated with production URLs
- [ ] API documentation reviewed and accurate
- [ ] Environment variables documented
- [ ] Deployment instructions tested
- [ ] Rollback plan documented

### Domain & DNS

- [ ] Domain name purchased/registered
- [ ] DNS records configured:
  - [ ] A record: `yourdomain.com` → Server IP
  - [ ] CNAME: `*.yourdomain.com` → `yourdomain.com` (wildcard)
  - [ ] Or individual CNAMEs for:
    - `api.yourdomain.com`
    - `dashboard.yourdomain.com`
    - `traefik.yourdomain.com`
- [ ] DNS propagation verified (use `dig` or online DNS checker)

---

## Server Setup

### Server Provisioning

- [ ] Cloud provider account created (AWS, DigitalOcean, Linode, etc.)
- [ ] Server instance created:
  - [ ] Minimum specs: 2 CPU, 4GB RAM, 50GB storage
  - [ ] Recommended: 4 CPU, 8GB RAM, 100GB storage
  - [ ] OS: Ubuntu 22.04 LTS or Debian 12
- [ ] Server accessible via SSH
  ```bash
  ssh root@your-server-ip
  ```

### System Updates

- [ ] System packages updated
  ```bash
  apt update && apt upgrade -y
  ```
- [ ] Timezone set
  ```bash
  timedatectl set-timezone America/New_York
  ```
- [ ] Hostname configured
  ```bash
  hostnamectl set-hostname your-hostname
  ```

### Docker Installation

- [ ] Docker Engine installed (NOT Docker Desktop)
  ```bash
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  ```
- [ ] Docker Compose installed
  ```bash
  apt install docker-compose-plugin -y
  ```
- [ ] Docker running and enabled
  ```bash
  systemctl enable docker
  systemctl start docker
  docker --version
  docker compose version
  ```

### User Setup

- [ ] Non-root user created
  ```bash
  adduser deploy
  usermod -aG sudo deploy
  usermod -aG docker deploy
  ```
- [ ] SSH key authentication configured for deploy user
- [ ] Password authentication disabled in SSH config (optional but recommended)

### Firewall

- [ ] UFW (Uncomplicated Firewall) enabled
  ```bash
  ufw allow OpenSSH
  ufw allow 80/tcp    # HTTP
  ufw allow 443/tcp   # HTTPS
  ufw enable
  ufw status
  ```

---

## Environment Configuration

### Traefik Proxy Setup

- [ ] Traefik directory created
  ```bash
  mkdir -p /root/code/traefik-public/
  ```
- [ ] `docker-compose.traefik.yml` copied to server
  ```bash
  rsync -a docker-compose.traefik.yml root@your-server:/root/code/traefik-public/
  ```
- [ ] Traefik public network created
  ```bash
  docker network create traefik-public
  ```
- [ ] Traefik environment variables set
  ```bash
  export USERNAME=admin
  export PASSWORD=<generate-secure-password>
  export HASHED_PASSWORD=$(openssl passwd -apr1 $PASSWORD)
  export DOMAIN=yourdomain.com
  export EMAIL=admin@yourdomain.com
  ```
- [ ] Traefik started
  ```bash
  cd /root/code/traefik-public/
  docker compose -f docker-compose.traefik.yml up -d
  ```
- [ ] Traefik dashboard accessible: https://traefik.yourdomain.com

### Application Environment Variables

- [ ] `.env` file created on server (DO NOT commit to git!)
  ```bash
  nano /root/code/your-app/.env
  ```

**Critical Variables** (must be changed from defaults):

- [ ] `ENVIRONMENT=production`
- [ ] `DOMAIN=yourdomain.com`
- [ ] `SECRET_KEY=<generated-secure-value>`
  ```bash
  python -c "import secrets; print(secrets.token_urlsafe(32))"
  ```
- [ ] `FIRST_SUPERUSER=your-email@yourdomain.com`
- [ ] `FIRST_SUPERUSER_PASSWORD=<generated-secure-value>`
- [ ] `POSTGRES_PASSWORD=<generated-secure-value>`

**SMTP Configuration** (for emails):

- [ ] `SMTP_HOST=smtp.mailgun.org` (or your provider)
- [ ] `SMTP_USER=postmaster@yourdomain.com`
- [ ] `SMTP_PASSWORD=<your-smtp-password>`
- [ ] `EMAILS_FROM_EMAIL=noreply@yourdomain.com`
- [ ] `SMTP_PORT=587`
- [ ] `SMTP_TLS=True`

**Optional but Recommended**:

- [ ] `SENTRY_DSN=<your-sentry-dsn>` (error tracking)
- [ ] `STACK_NAME=your-app-production`
- [ ] `PROJECT_NAME=Your App Name`

### CORS Configuration

- [ ] `BACKEND_CORS_ORIGINS` updated for production
  ```env
  BACKEND_CORS_ORIGINS="https://dashboard.yourdomain.com,https://yourdomain.com"
  ```

---

## Database Setup

### Database Choice

Choose one:

#### Option A: Use Docker PostgreSQL (Simple)
- [ ] Using database from `docker-compose.yml`
- [ ] Volume configured for persistence
- [ ] Backup strategy planned

#### Option B: Managed Database (Recommended for Production)
- [ ] Managed PostgreSQL instance created (AWS RDS, DigitalOcean, etc.)
- [ ] Database credentials obtained
- [ ] `.env` updated:
  ```env
  POSTGRES_SERVER=your-db-host.region.provider.com
  POSTGRES_PORT=5432
  POSTGRES_USER=your-db-user
  POSTGRES_PASSWORD=<db-password>
  POSTGRES_DB=your-db-name
  ```
- [ ] Security group/firewall allows connection from application server

### Database Backups

- [ ] Backup script created
  ```bash
  #!/bin/bash
  docker exec postgres pg_dump -U postgres app > backup-$(date +%Y%m%d).sql
  ```
- [ ] Cron job scheduled for daily backups
  ```bash
  0 2 * * * /path/to/backup-script.sh
  ```
- [ ] Backup retention policy defined
- [ ] Restore procedure tested

---

## Application Deployment

### Code Deployment

- [ ] Git repository cloned to server
  ```bash
  cd /root/code/
  git clone git@github.com:your-username/your-repo.git
  cd your-repo
  ```
- [ ] Correct branch/tag checked out
  ```bash
  git checkout v1.0.0  # or main
  ```

### Build & Start

- [ ] Docker images built
  ```bash
  docker compose -f docker-compose.yml build
  ```
- [ ] Application started (WITHOUT docker-compose.override.yml)
  ```bash
  docker compose -f docker-compose.yml up -d
  ```
- [ ] All containers running
  ```bash
  docker compose ps
  ```
- [ ] Database migrations applied
  ```bash
  docker compose exec backend alembic upgrade head
  ```
- [ ] First superuser created (automatic on first run)

### Verify Deployment

- [ ] Backend health check: https://api.yourdomain.com/api/v1/utils/health-check/
- [ ] Frontend loads: https://dashboard.yourdomain.com
- [ ] Can log in with superuser credentials
- [ ] API docs accessible: https://api.yourdomain.com/docs
- [ ] SSL certificate issued and valid
- [ ] No console errors in browser
- [ ] Check logs for errors:
  ```bash
  docker compose logs backend | grep ERROR
  docker compose logs frontend | grep ERROR
  ```

---

## Post-Deployment

### Monitoring Setup

- [ ] Application logs configured
  ```bash
  docker compose logs -f
  ```
- [ ] Log rotation configured
  ```bash
  # Add to /etc/docker/daemon.json
  {
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "10m",
      "max-file": "3"
    }
  }
  ```
- [ ] Error tracking enabled (Sentry recommended)
- [ ] Uptime monitoring configured (UptimeRobot, Pingdom, etc.)
- [ ] Disk space monitoring
  ```bash
  df -h
  ```

### Performance Testing

- [ ] Load testing performed (optional but recommended)
- [ ] Response times acceptable
- [ ] Database queries optimized
- [ ] CDN configured for static assets (optional)

### Email Testing

- [ ] Password reset email works
- [ ] User registration email works
- [ ] SMTP connection verified
  ```bash
  docker compose exec backend python -c "from app.utils import send_email; print('Test')"
  ```

---

## Security Hardening

### Application Security

- [ ] All `changethis` values replaced in `.env`
- [ ] Debug mode disabled (`ENVIRONMENT=production`)
- [ ] Secrets not committed to git
- [ ] `.env` file permissions restricted
  ```bash
  chmod 600 .env
  ```

### Server Security

- [ ] Fail2ban installed and configured
  ```bash
  apt install fail2ban
  systemctl enable fail2ban
  systemctl start fail2ban
  ```
- [ ] SSH key authentication enforced
- [ ] Root login disabled
  ```bash
  # In /etc/ssh/sshd_config
  PermitRootLogin no
  PasswordAuthentication no
  ```
- [ ] Automatic security updates enabled
  ```bash
  apt install unattended-upgrades
  dpkg-reconfigure -plow unattended-upgrades
  ```

### SSL/TLS

- [ ] HTTPS enforced (HTTP redirects to HTTPS)
- [ ] SSL certificate valid and auto-renewing
- [ ] SSL Labs test passed (A+ rating)
  - https://www.ssllabs.com/ssltest/

### Database Security

- [ ] Database not exposed to public internet
- [ ] Strong database password used
- [ ] Database backups encrypted (if applicable)

### CORS & Headers

- [ ] CORS restricted to your domains only
- [ ] Security headers configured:
  - [ ] X-Content-Type-Options
  - [ ] X-Frame-Options
  - [ ] Content-Security-Policy
  - [ ] Strict-Transport-Security

---

## Monitoring & Maintenance

### Health Checks

Set up automated checks:

- [ ] Application uptime monitoring
- [ ] SSL certificate expiry monitoring
- [ ] Disk space alerts
- [ ] Memory usage alerts
- [ ] Database connection monitoring

### Backup Verification

- [ ] Database backups running automatically
- [ ] Backup restoration tested successfully
- [ ] Off-site backup storage configured
- [ ] Backup retention policy implemented

### Update Strategy

- [ ] Update schedule planned (security patches)
- [ ] Rollback procedure documented
- [ ] Staging environment available for testing updates

### Documentation

- [ ] Server access credentials documented (securely!)
- [ ] Deployment procedure documented
- [ ] Rollback procedure documented
- [ ] Emergency contacts listed
- [ ] Runbook created for common issues

---

## CI/CD Setup (Optional)

### GitHub Actions

- [ ] GitHub repository secrets configured:
  - `DOMAIN_PRODUCTION`
  - `SECRET_KEY`
  - `FIRST_SUPERUSER`
  - `FIRST_SUPERUSER_PASSWORD`
  - `POSTGRES_PASSWORD`
  - `LATEST_CHANGES` (optional)
  - `SMOKESHOW_AUTH_KEY` (optional)
- [ ] GitHub Actions runner installed on server
  ```bash
  # Follow: https://docs.github.com/en/actions/hosting-your-own-runners
  ```
- [ ] Runner service enabled
- [ ] Test deployment workflow
- [ ] Auto-deploy configured for main branch (optional)

---

## Final Checks

Before announcing your deployment:

- [ ] **Functionality**: All features work as expected
- [ ] **Performance**: Page load times acceptable (<3 seconds)
- [ ] **Security**: All security items above completed
- [ ] **Monitoring**: Alerts configured and tested
- [ ] **Backups**: Verified and tested
- [ ] **Documentation**: Complete and accessible
- [ ] **Team**: Everyone knows how to access and troubleshoot
- [ ] **Users**: Communication sent about new deployment

---

## Post-Launch

### First 24 Hours

- [ ] Monitor logs closely
- [ ] Check error rates
- [ ] Verify backups completed
- [ ] User feedback collected

### First Week

- [ ] Performance metrics reviewed
- [ ] Error tracking reviewed
- [ ] Backup verification
- [ ] Security scan performed

### Ongoing

- [ ] Weekly backup checks
- [ ] Monthly security updates
- [ ] Quarterly performance reviews
- [ ] Annual SSL certificate renewal (auto or manual)

---

## Emergency Contacts

Document these before deployment:

- **DevOps Lead**: Name, Phone, Email
- **Database Admin**: Name, Phone, Email
- **Hosting Provider**: Support Phone/Email
- **DNS Provider**: Support Phone/Email
- **On-Call Schedule**: Who's responsible when

---

## Rollback Procedure

If something goes wrong:

1. **Stop the current deployment**
   ```bash
   docker compose down
   ```

2. **Checkout previous working version**
   ```bash
   git checkout <previous-tag>
   ```

3. **Restore database backup** (if needed)
   ```bash
   docker exec -i postgres psql -U postgres app < backup-YYYYMMDD.sql
   ```

4. **Restart application**
   ```bash
   docker compose -f docker-compose.yml up -d
   ```

5. **Verify rollback successful**

6. **Communicate incident to team**

---

## Resources

- [Official Deployment Guide](../deployment.md)
- [Architecture Documentation](../ARCHITECTURE.md)
- [Troubleshooting Guide](./troubleshooting.md)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [Docker Production Guide](https://docs.docker.com/compose/production/)

---

**Remember**: Take your time with each step. A careful deployment prevents future emergencies! 🚀
