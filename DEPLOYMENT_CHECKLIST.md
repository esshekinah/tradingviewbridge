# Dokploy Deployment Checklist

Complete checklist for deploying TradingView Webhook Bridge on Dokploy.

**Domain:** `ctrader.emmanuelshekinah.co.za`
**Application:** TradingView Webhook Bridge for cTrader
**Deployment Date:** _______________

---

## Pre-Deployment

### Prerequisites
- [ ] Ubuntu 20.04+ VPS provisioned
- [ ] Domain `ctrader.emmanuelshekinah.co.za` registered
- [ ] Domain DNS pointing to VPS IP
- [ ] SSH access to VPS verified
- [ ] Sudo privileges confirmed
- [ ] Application files ready (main.py, requirements.txt, Dockerfile)

### DNS Configuration
- [ ] A record created: `ctrader.emmanuelshekinah.co.za` → `<VPS-IP>`
- [ ] DNS propagation verified: `nslookup ctrader.emmanuelshekinah.co.za`
- [ ] TTL set appropriately (recommended: 3600)

### VPS Preparation
- [ ] System updated: `sudo apt-get update && sudo apt-get upgrade -y`
- [ ] SSH key configured for passwordless access
- [ ] Firewall rules planned
- [ ] Backup strategy in place

---

## System Setup

### Automated Setup (Recommended)
- [ ] Downloaded setup script: `setup-dokploy.sh`
- [ ] Updated email in script (for Let's Encrypt)
- [ ] Ran setup script: `sudo bash setup-dokploy.sh`
- [ ] Setup completed without errors
- [ ] All services started successfully

### Manual Setup (If needed)
- [ ] Docker installed: `docker --version`
- [ ] Docker Compose installed: `docker-compose --version`
- [ ] Dokploy installed: `dokploy --version`
- [ ] Nginx installed: `nginx -v`
- [ ] Certbot installed: `certbot --version`

### Directory Structure
- [ ] Application directory created: `/opt/tradingview-webhook`
- [ ] Log directory created: `/var/log/tradingview-webhook`
- [ ] Permissions set correctly
- [ ] Application files uploaded/cloned

---

## Firewall Configuration

### UFW Rules
- [ ] UFW enabled: `sudo ufw enable`
- [ ] SSH allowed: `sudo ufw allow 22/tcp`
- [ ] HTTP allowed: `sudo ufw allow 80/tcp`
- [ ] HTTPS allowed: `sudo ufw allow 443/tcp`
- [ ] App port allowed: `sudo ufw allow 25345/tcp`
- [ ] Rules verified: `sudo ufw status numbered`

### Port Verification
- [ ] Port 22 (SSH) listening
- [ ] Port 80 (HTTP) listening
- [ ] Port 443 (HTTPS) listening
- [ ] Port 25345 (App) listening

---

## Nginx Configuration

### Installation
- [ ] Nginx installed
- [ ] Nginx service enabled: `sudo systemctl enable nginx`
- [ ] Nginx service started: `sudo systemctl start nginx`

### Configuration
- [ ] Nginx config created: `/etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za`
- [ ] Site enabled: `sudo ln -s /etc/nginx/sites-available/... /etc/nginx/sites-enabled/`
- [ ] Default site removed: `sudo rm /etc/nginx/sites-enabled/default`
- [ ] Configuration tested: `sudo nginx -t`
- [ ] Nginx reloaded: `sudo systemctl reload nginx`

### Reverse Proxy
- [ ] Proxy pass configured to localhost:25345
- [ ] Headers configured correctly
- [ ] Buffering configured
- [ ] Timeouts set appropriately

---

## SSL/HTTPS Setup

### Certificate Creation
- [ ] Certbot installed
- [ ] Webroot directory created: `/var/www/certbot`
- [ ] Certificate created: `sudo certbot certonly --webroot ...`
- [ ] Certificate verified: `sudo certbot certificates`
- [ ] Certificate path: `/etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/`

### Certificate Configuration
- [ ] Nginx SSL directives configured
- [ ] Certificate path correct in Nginx config
- [ ] Private key path correct in Nginx config
- [ ] SSL protocols configured (TLSv1.2, TLSv1.3)
- [ ] Ciphers configured

### Auto-Renewal
- [ ] Certbot timer enabled: `sudo systemctl enable certbot.timer`
- [ ] Certbot timer started: `sudo systemctl start certbot.timer`
- [ ] Renewal test passed: `sudo certbot renew --dry-run`
- [ ] Renewal scheduled

---

## Dokploy Configuration

### Dashboard Access
- [ ] Dokploy service running: `sudo systemctl status dokploy`
- [ ] Dashboard accessible: `http://<VPS-IP>:3000`
- [ ] Admin account created
- [ ] Initial setup completed

### Project Creation
- [ ] Project created: "TradingView Webhook Bridge"
- [ ] Project description added
- [ ] Project settings configured

### Application Creation
- [ ] Application created: "tradingview-webhook"
- [ ] Application type: Docker
- [ ] Application description added

### Docker Configuration
- [ ] Dockerfile path: `./Dockerfile`
- [ ] Build context: `/opt/tradingview-webhook`
- [ ] Container port: 25345
- [ ] Published port: 25345
- [ ] Protocol: TCP

### Environment Variables
- [ ] PYTHONUNBUFFERED=1
- [ ] LOG_LEVEL=INFO
- [ ] ENVIRONMENT=production
- [ ] Additional variables added as needed

### Restart Policy
- [ ] Restart policy: `unless-stopped`
- [ ] Max retry count: 5

### Health Check
- [ ] Health check enabled
- [ ] Command: `curl -f http://localhost:25345/health || exit 1`
- [ ] Interval: 30s
- [ ] Timeout: 10s
- [ ] Retries: 3
- [ ] Start period: 5s

### Volumes
- [ ] Host path: `/var/log/tradingview-webhook`
- [ ] Container path: `/app/logs`
- [ ] Read only: No
- [ ] Volume created and mounted

### Resource Limits
- [ ] CPU limit: 1 core
- [ ] Memory limit: 512MB
- [ ] CPU reservation: 0.5 core
- [ ] Memory reservation: 256MB

---

## Application Deployment

### Pre-Deployment
- [ ] Application files verified
- [ ] Dockerfile tested locally (if possible)
- [ ] requirements.txt verified
- [ ] main.py syntax checked
- [ ] No secrets in code

### Deployment
- [ ] Deploy button clicked in Dokploy
- [ ] Deployment progress monitored
- [ ] Build completed successfully
- [ ] Container started successfully
- [ ] No deployment errors

### Post-Deployment
- [ ] Container running: `docker ps | grep tradingview`
- [ ] Port 25345 listening: `sudo netstat -tlnp | grep 25345`
- [ ] Health check passing: `curl http://localhost:25345/health`

---

## Testing & Verification

### Local Testing
- [ ] Health endpoint: `curl http://localhost:25345/health`
- [ ] Root endpoint: `curl http://localhost:25345/`
- [ ] Webhook endpoint: `curl -X POST http://localhost:25345/webhook ...`
- [ ] Signal endpoint: `curl http://localhost:25345/signal`

### HTTPS Testing
- [ ] HTTPS access: `curl https://ctrader.emmanuelshekinah.co.za/health`
- [ ] HTTP redirect: `curl -I http://ctrader.emmanuelshekinah.co.za/`
- [ ] Certificate valid: `openssl s_client -connect ctrader.emmanuelshekinah.co.za:443`
- [ ] Security headers present

### Webhook Testing
- [ ] Send test alert: `curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook ...`
- [ ] Alert received and logged
- [ ] Signal stored correctly
- [ ] Response JSON valid

### Performance Testing
- [ ] Response time acceptable
- [ ] No errors in logs
- [ ] Memory usage normal
- [ ] CPU usage normal

---

## Monitoring & Logging

### Log Configuration
- [ ] Docker logs accessible: `docker logs tradingview-webhook`
- [ ] Persistent logs directory: `/var/log/tradingview-webhook`
- [ ] Log rotation configured
- [ ] Log files being written

### Monitoring Setup
- [ ] Monitoring script available: `monitor.sh`
- [ ] Health checks running
- [ ] Alerts configured (if applicable)
- [ ] Dashboard accessible

### Log Rotation
- [ ] Logrotate config created: `/etc/logrotate.d/tradingview-webhook`
- [ ] Rotation schedule: daily
- [ ] Retention: 14 days
- [ ] Compression enabled

---

## TradingView Configuration

### Webhook Setup
- [ ] TradingView account accessed
- [ ] Alert webhook URL configured: `https://ctrader.emmanuelshekinah.co.za/webhook`
- [ ] Test alert sent
- [ ] Alert received and logged
- [ ] Webhook working correctly

### Alert Testing
- [ ] BUY alert tested
- [ ] SELL alert tested
- [ ] Different symbols tested
- [ ] Alerts logged correctly

---

## Security Hardening

### Nginx Security
- [ ] Security headers configured
- [ ] HSTS enabled
- [ ] X-Frame-Options set
- [ ] X-Content-Type-Options set
- [ ] X-XSS-Protection set

### SSL/TLS Security
- [ ] TLSv1.2+ only
- [ ] Strong ciphers configured
- [ ] Session caching enabled
- [ ] OCSP stapling (optional)

### Firewall Security
- [ ] UFW active and configured
- [ ] Only necessary ports open
- [ ] SSH restricted (if possible)
- [ ] Rate limiting configured (optional)

### Application Security
- [ ] No secrets in code
- [ ] Input validation enabled
- [ ] Error handling proper
- [ ] Logging configured

---

## Backup & Recovery

### Backup Strategy
- [ ] Application files backed up
- [ ] Configuration files backed up
- [ ] Logs backed up
- [ ] Backup location: _______________
- [ ] Backup frequency: _______________

### Recovery Plan
- [ ] Recovery procedure documented
- [ ] Restore tested
- [ ] RTO defined: _______________
- [ ] RPO defined: _______________

---

## Documentation

### Created Documents
- [ ] README.md - Application documentation
- [ ] DOKPLOY_DEPLOYMENT.md - Detailed deployment guide
- [ ] QUICK_START.md - Quick start guide
- [ ] DEPLOYMENT_CHECKLIST.md - This checklist
- [ ] Troubleshooting guide available
- [ ] Monitoring guide available

### Runbooks
- [ ] Deployment runbook created
- [ ] Troubleshooting runbook created
- [ ] Monitoring runbook created
- [ ] Escalation procedures documented

---

## Post-Deployment

### Verification
- [ ] All services running
- [ ] All endpoints responding
- [ ] Logs being written
- [ ] Monitoring active
- [ ] Alerts configured

### Optimization
- [ ] Performance baseline established
- [ ] Resource usage monitored
- [ ] Caching configured (if applicable)
- [ ] Database optimized (if applicable)

### Maintenance
- [ ] Update schedule established
- [ ] Backup schedule established
- [ ] Monitoring schedule established
- [ ] Review schedule established

---

## Sign-Off

**Deployment Completed By:** _______________
**Date:** _______________
**Time:** _______________

**Verified By:** _______________
**Date:** _______________

**Notes:**
```
_________________________________________________________________

_________________________________________________________________

_________________________________________________________________
```

---

## Troubleshooting Quick Links

If issues occur, refer to:
- DOKPLOY_DEPLOYMENT.md - Troubleshooting section
- troubleshoot.sh - Automated troubleshooting script
- monitor.sh - Real-time monitoring script

---

## Support Contacts

- **Dokploy Support:** https://dokploy.com/docs
- **Nginx Support:** https://nginx.org/en/docs/
- **Let's Encrypt Support:** https://letsencrypt.org/
- **Docker Support:** https://docs.docker.com/

---

**Last Updated:** May 27, 2026
**Version:** 1.0.0
