# Commands Reference - TradingView Webhook Bridge

Quick reference for all commands needed to deploy and manage the application on Dokploy.

---

## Initial Setup Commands

### 1. Connect to VPS
```bash
ssh user@your-vps-ip
```

### 2. Download Setup Script
```bash
curl -O https://raw.githubusercontent.com/your-repo/setup-dokploy.sh
chmod +x setup-dokploy.sh
```

### 3. Run Automated Setup
```bash
sudo bash setup-dokploy.sh
```

### 4. Upload Application Files
```bash
# From local machine
scp -r main.py requirements.txt Dockerfile docker-compose.yml \
  user@your-vps-ip:/opt/tradingview-webhook/
```

---

## System Management

### Update System
```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### Check System Info
```bash
# OS version
lsb_release -a

# Disk usage
df -h

# Memory usage
free -h

# CPU info
nproc
```

### Reboot System
```bash
sudo reboot
```

---

## Docker Commands

### Check Docker Status
```bash
docker --version
docker ps
docker ps -a
```

### View Container Logs
```bash
# Last 20 lines
docker logs -n 20 tradingview-webhook-bridge

# Follow logs
docker logs -f tradingview-webhook-bridge

# Last 100 lines
docker logs --tail 100 tradingview-webhook-bridge
```

### Manage Container
```bash
# Start container
docker start tradingview-webhook-bridge

# Stop container
docker stop tradingview-webhook-bridge

# Restart container
docker restart tradingview-webhook-bridge

# Remove container
docker rm tradingview-webhook-bridge
```

### Build Docker Image
```bash
cd /opt/tradingview-webhook
docker build -t tradingview-webhook-bridge .
```

### Run Container Manually
```bash
docker run -d \
  --name tradingview-webhook \
  -p 25345:25345 \
  -e PYTHONUNBUFFERED=1 \
  -e LOG_LEVEL=INFO \
  --restart unless-stopped \
  tradingview-webhook-bridge
```

### Monitor Container Resources
```bash
# Real-time stats
docker stats tradingview-webhook-bridge

# One-time stats
docker stats --no-stream tradingview-webhook-bridge
```

### Docker Compose Commands
```bash
cd /opt/tradingview-webhook

# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Rebuild images
docker-compose build

# Restart services
docker-compose restart
```

---

## Dokploy Commands

### Check Dokploy Status
```bash
sudo systemctl status dokploy
dokploy --version
```

### Manage Dokploy Service
```bash
# Start
sudo systemctl start dokploy

# Stop
sudo systemctl stop dokploy

# Restart
sudo systemctl restart dokploy

# Enable on boot
sudo systemctl enable dokploy

# View logs
sudo journalctl -u dokploy -f

# View last 50 lines
sudo journalctl -u dokploy -n 50
```

---

## Nginx Commands

### Check Nginx Status
```bash
sudo systemctl status nginx
nginx -v
```

### Manage Nginx Service
```bash
# Start
sudo systemctl start nginx

# Stop
sudo systemctl stop nginx

# Restart
sudo systemctl restart nginx

# Reload (graceful)
sudo systemctl reload nginx

# Enable on boot
sudo systemctl enable nginx
```

### Nginx Configuration
```bash
# Test configuration
sudo nginx -t

# View configuration
sudo cat /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za

# Edit configuration
sudo nano /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za

# Enable site
sudo ln -s /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za \
  /etc/nginx/sites-enabled/

# Disable site
sudo rm /etc/nginx/sites-enabled/ctrader.emmanuelshekinah.co.za
```

### Nginx Logs
```bash
# Access logs
tail -f /var/log/nginx/ctrader.access.log

# Error logs
tail -f /var/log/nginx/ctrader.error.log

# Last 20 lines
tail -20 /var/log/nginx/ctrader.access.log

# Search logs
grep "error" /var/log/nginx/ctrader.error.log

# Count requests
wc -l /var/log/nginx/ctrader.access.log
```

---

## SSL/HTTPS Commands

### Certbot Commands
```bash
# Check installed certificates
sudo certbot certificates

# Create certificate
sudo certbot certonly --webroot \
  -w /var/www/certbot \
  -d ctrader.emmanuelshekinah.co.za \
  --email your-email@example.com \
  --agree-tos \
  --non-interactive

# Renew certificate (manual)
sudo certbot renew --force-renewal

# Test renewal (dry-run)
sudo certbot renew --dry-run

# Delete certificate
sudo certbot delete --cert-name ctrader.emmanuelshekinah.co.za
```

### Certificate Verification
```bash
# Check certificate details
openssl x509 -in /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/fullchain.pem -noout -text

# Check expiry date
openssl x509 -in /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/fullchain.pem -noout -enddate

# Check certificate chain
openssl s_client -connect ctrader.emmanuelshekinah.co.za:443 -showcerts

# Verify certificate
openssl verify /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/fullchain.pem
```

### Certbot Timer
```bash
# Enable auto-renewal
sudo systemctl enable certbot.timer

# Start timer
sudo systemctl start certbot.timer

# Check timer status
sudo systemctl status certbot.timer

# View timer logs
sudo journalctl -u certbot.timer -f
```

---

## Firewall Commands

### UFW Management
```bash
# Enable firewall
sudo ufw enable

# Disable firewall
sudo ufw disable

# Check status
sudo ufw status

# Verbose status
sudo ufw status verbose

# Numbered status
sudo ufw status numbered
```

### UFW Rules
```bash
# Allow port
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 25345/tcp
sudo ufw allow 22/tcp

# Deny port
sudo ufw deny 8080/tcp

# Delete rule
sudo ufw delete allow 8080/tcp

# Allow from specific IP
sudo ufw allow from 203.0.113.0 to any port 3000

# Reload rules
sudo ufw reload

# Reset firewall
sudo ufw reset
```

---

## Network Commands

### DNS Verification
```bash
# Check DNS resolution
nslookup ctrader.emmanuelshekinah.co.za

# Detailed DNS lookup
dig ctrader.emmanuelshekinah.co.za

# Check specific DNS server
nslookup ctrader.emmanuelshekinah.co.za 8.8.8.8

# Flush DNS cache
sudo systemctl restart systemd-resolved
```

### Port Verification
```bash
# Check listening ports
sudo netstat -tlnp

# Check specific port
sudo netstat -tlnp | grep 25345

# Alternative: using ss
sudo ss -tlnp

# Check if port is open
nc -zv ctrader.emmanuelshekinah.co.za 443
```

### Network Testing
```bash
# Ping
ping ctrader.emmanuelshekinah.co.za

# Traceroute
traceroute ctrader.emmanuelshekinah.co.za

# Check connectivity
curl -I https://ctrader.emmanuelshekinah.co.za

# Verbose curl
curl -v https://ctrader.emmanuelshekinah.co.za
```

---

## Application Testing

### Health Check
```bash
# Local health check
curl http://localhost:25345/health

# HTTPS health check
curl https://ctrader.emmanuelshekinah.co.za/health

# Verbose health check
curl -v https://ctrader.emmanuelshekinah.co.za/health
```

### API Testing
```bash
# Get API info
curl https://ctrader.emmanuelshekinah.co.za/

# Send test webhook
curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "XAUUSD",
    "action": "BUY",
    "price": "3345.12",
    "time": "2026-05-27T10:00:00Z"
  }'

# Get latest signal
curl https://ctrader.emmanuelshekinah.co.za/signal

# Pretty print JSON
curl https://ctrader.emmanuelshekinah.co.za/signal | jq .
```

---

## Monitoring Commands

### System Monitoring
```bash
# Interactive monitoring
htop

# Disk I/O monitoring
iotop

# Process monitoring
top

# Memory usage
free -h

# Disk usage
df -h

# Load average
uptime
```

### Service Monitoring
```bash
# Check all services
sudo systemctl status

# List running services
sudo systemctl list-units --type=service --state=running

# Check specific service
sudo systemctl status docker
sudo systemctl status nginx
sudo systemctl status dokploy
```

### Log Monitoring
```bash
# Real-time monitoring script
bash monitor.sh

# Docker logs
docker logs -f tradingview-webhook-bridge

# Nginx access logs
tail -f /var/log/nginx/ctrader.access.log

# Nginx error logs
tail -f /var/log/nginx/ctrader.error.log

# System logs
sudo journalctl -f

# Specific service logs
sudo journalctl -u dokploy -f
```

---

## Troubleshooting Commands

### Run Troubleshooting Script
```bash
sudo bash troubleshoot.sh
```

### Manual Troubleshooting
```bash
# Check if application is running
docker ps | grep tradingview

# Check application logs
docker logs tradingview-webhook-bridge

# Check if port is listening
sudo netstat -tlnp | grep 25345

# Test local connection
curl http://localhost:25345/health

# Check Nginx configuration
sudo nginx -t

# Check firewall rules
sudo ufw status

# Check certificate
sudo certbot certificates

# Check DNS
nslookup ctrader.emmanuelshekinah.co.za

# Check system resources
free -h
df -h
```

### Common Fixes
```bash
# Restart Docker
sudo systemctl restart docker

# Restart Nginx
sudo systemctl reload nginx

# Restart application
docker restart tradingview-webhook-bridge

# Renew certificate
sudo certbot renew --force-renewal

# Reload firewall
sudo ufw reload

# Clear Docker logs
docker logs --tail 0 tradingview-webhook-bridge
```

---

## File Management

### Application Directory
```bash
# Navigate to app directory
cd /opt/tradingview-webhook

# List files
ls -la

# View main.py
cat main.py

# Edit main.py
nano main.py

# View logs
ls -la /var/log/tradingview-webhook/

# View recent logs
tail -f /var/log/tradingview-webhook/app.log
```

### Configuration Files
```bash
# Nginx configuration
sudo cat /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za

# Docker Compose
cat /opt/tradingview-webhook/docker-compose.yml

# Dockerfile
cat /opt/tradingview-webhook/Dockerfile

# Requirements
cat /opt/tradingview-webhook/requirements.txt
```

---

## Backup Commands

### Backup Application
```bash
# Backup application directory
sudo tar -czf tradingview-webhook-backup-$(date +%Y%m%d).tar.gz \
  /opt/tradingview-webhook/

# Backup logs
sudo tar -czf tradingview-logs-backup-$(date +%Y%m%d).tar.gz \
  /var/log/tradingview-webhook/

# Backup Nginx config
sudo tar -czf nginx-config-backup-$(date +%Y%m%d).tar.gz \
  /etc/nginx/sites-available/
```

### Restore from Backup
```bash
# Restore application
sudo tar -xzf tradingview-webhook-backup-20260527.tar.gz -C /

# Restore logs
sudo tar -xzf tradingview-logs-backup-20260527.tar.gz -C /

# Restore Nginx config
sudo tar -xzf nginx-config-backup-20260527.tar.gz -C /
```

---

## Useful Aliases

Add to `~/.bashrc` for convenience:

```bash
# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dl='docker logs -f tradingview-webhook-bridge'
alias dps='docker ps'

# Nginx aliases
alias nginx-test='sudo nginx -t'
alias nginx-reload='sudo systemctl reload nginx'
alias nginx-logs='tail -f /var/log/nginx/ctrader.access.log'

# Application aliases
alias app-dir='cd /opt/tradingview-webhook'
alias app-logs='tail -f /var/log/tradingview-webhook/app.log'
alias app-health='curl https://ctrader.emmanuelshekinah.co.za/health'

# System aliases
alias sysmon='htop'
alias diskuse='df -h'
alias memuse='free -h'
```

---

## Emergency Commands

### Stop Everything
```bash
# Stop application
docker stop tradingview-webhook-bridge

# Stop Nginx
sudo systemctl stop nginx

# Stop Docker
sudo systemctl stop docker
```

### Start Everything
```bash
# Start Docker
sudo systemctl start docker

# Start Nginx
sudo systemctl start nginx

# Start application
docker start tradingview-webhook-bridge
```

### Emergency Restart
```bash
# Full restart
sudo systemctl restart docker
sudo systemctl restart nginx
docker restart tradingview-webhook-bridge
```

### Check Everything
```bash
# Quick health check
echo "=== Docker ===" && docker ps
echo "=== Nginx ===" && sudo systemctl status nginx
echo "=== Application ===" && curl -s http://localhost:25345/health
echo "=== Firewall ===" && sudo ufw status
echo "=== Disk ===" && df -h /
```

---

## Performance Tuning

### Increase File Descriptors
```bash
# Check current limit
ulimit -n

# Increase limit
ulimit -n 65536

# Make permanent (add to /etc/security/limits.conf)
sudo bash -c 'echo "* soft nofile 65536" >> /etc/security/limits.conf'
sudo bash -c 'echo "* hard nofile 65536" >> /etc/security/limits.conf'
```

### Optimize Nginx
```bash
# Check worker processes
grep worker_processes /etc/nginx/nginx.conf

# Check worker connections
grep worker_connections /etc/nginx/nginx.conf
```

### Monitor Performance
```bash
# CPU usage
top -b -n 1 | head -20

# Memory usage
ps aux --sort=-%mem | head -10

# Disk I/O
iostat -x 1 5

# Network
iftop
```

---

## Documentation

### View Documentation
```bash
# README
cat /opt/tradingview-webhook/README.md

# Deployment guide
cat DOKPLOY_DEPLOYMENT.md

# Quick start
cat QUICK_START.md

# Checklist
cat DEPLOYMENT_CHECKLIST.md

# This reference
cat COMMANDS_REFERENCE.md
```

---

**Last Updated:** May 27, 2026
**Version:** 1.0.0
