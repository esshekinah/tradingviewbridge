# Dokploy Deployment Guide - TradingView Webhook Bridge

Complete guide to deploy the FastAPI TradingView webhook bridge on Dokploy with HTTPS, reverse proxy, and persistent logging.

**Domain:** `ctrader.emmanuelshekinah.co.za`
**Port:** `25345`
**Application:** TradingView Webhook Bridge for cTrader

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Dokploy Installation](#dokploy-installation)
3. [Application Setup](#application-setup)
4. [Firewall Configuration](#firewall-configuration)
5. [Dokploy Configuration](#dokploy-configuration)
6. [Nginx Reverse Proxy](#nginx-reverse-proxy)
7. [HTTPS with Let's Encrypt](#https-with-lets-encrypt)
8. [Environment Variables](#environment-variables)
9. [Monitoring & Logs](#monitoring--logs)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements

- Ubuntu 20.04 LTS or later
- Docker and Docker Compose installed
- Dokploy installed
- Domain pointing to your VPS IP
- SSH access to your VPS
- Sudo privileges

### Verify Prerequisites

```bash
# Check Ubuntu version
lsb_release -a

# Check Docker installation
docker --version
docker-compose --version

# Check Dokploy installation
dokploy --version

# Check domain DNS resolution
nslookup ctrader.emmanuelshekinah.co.za
```

---

## Dokploy Installation

If Dokploy is not installed, follow these steps:

### 1. Install Dokploy

```bash
# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Install Dokploy (official installation)
curl -sSL https://dokploy.com/install.sh | sh

# Verify installation
dokploy --version
```

### 2. Start Dokploy Service

```bash
# Enable Dokploy service
sudo systemctl enable dokploy
sudo systemctl start dokploy

# Check status
sudo systemctl status dokploy

# View Dokploy logs
sudo journalctl -u dokploy -f
```

### 3. Access Dokploy Dashboard

- Open browser: `http://<your-vps-ip>:3000`
- Complete initial setup
- Create admin account
- Configure basic settings

---

## Application Setup

### 1. Prepare Application Files

On your VPS, create the application directory:

```bash
# Create application directory
sudo mkdir -p /opt/tradingview-webhook
cd /opt/tradingview-webhook

# Set proper permissions
sudo chown $USER:$USER /opt/tradingview-webhook
```

### 2. Upload Application Files

Copy your application files to the VPS:

```bash
# From your local machine
scp -r main.py requirements.txt Dockerfile docker-compose.yml \
  user@your-vps-ip:/opt/tradingview-webhook/
```

Or clone from Git:

```bash
cd /opt/tradingview-webhook
git clone <your-repo-url> .
```

### 3. Verify File Structure

```bash
ls -la /opt/tradingview-webhook/
# Expected output:
# main.py
# requirements.txt
# Dockerfile
# docker-compose.yml
# README.md
```

---

## Firewall Configuration

### 1. Enable UFW (Uncomplicated Firewall)

```bash
# Enable UFW
sudo ufw enable

# Verify status
sudo ufw status

# Expected output: Status: active
```

### 2. Configure UFW Rules

```bash
# Allow SSH (critical - do this first!)
sudo ufw allow 22/tcp

# Allow HTTP
sudo ufw allow 80/tcp

# Allow HTTPS
sudo ufw allow 443/tcp

# Allow Dokploy dashboard (optional, restrict to your IP)
sudo ufw allow 3000/tcp

# Allow internal Docker port (optional)
sudo ufw allow 25345/tcp

# Verify rules
sudo ufw status numbered

# Expected output:
# Status: active
#      To                         Action      From
#      --                         ------      ----
# 1.   22/tcp                     ALLOW       Anywhere
# 2.   80/tcp                     ALLOW       Anywhere
# 3.   443/tcp                    ALLOW       Anywhere
# 4.   3000/tcp                   ALLOW       Anywhere
# 5.   25345/tcp                  ALLOW       Anywhere
```

### 3. Restrict Dokploy Dashboard (Recommended)

```bash
# Remove open access to port 3000
sudo ufw delete allow 3000/tcp

# Allow only from your IP (replace with your actual IP)
sudo ufw allow from 203.0.113.0 to any port 3000

# Or use SSH tunnel instead (more secure)
# ssh -L 3000:localhost:3000 user@your-vps-ip
```

---

## Dokploy Configuration

### 1. Access Dokploy Dashboard

```
http://<your-vps-ip>:3000
```

### 2. Create New Project

1. Click "Projects" in sidebar
2. Click "Create Project"
3. Enter project details:
   - **Name:** `TradingView Webhook Bridge`
   - **Description:** `FastAPI webhook receiver for cTrader`
   - Click "Create"

### 3. Create New Application

1. Click on your project
2. Click "Create Application"
3. Select "Docker" deployment type
4. Enter application details:
   - **Name:** `tradingview-webhook`
   - **Description:** `cTrader webhook bridge`
   - Click "Create"

### 4. Configure Docker Settings

In the application settings:

#### General Tab
- **Name:** `tradingview-webhook`
- **Description:** `TradingView webhook bridge for cTrader`

#### Docker Tab
- **Docker Compose File:** Leave empty (will use Dockerfile)
- **Dockerfile Path:** `./Dockerfile`
- **Build Context:** `/opt/tradingview-webhook`

#### Ports Tab
- **Container Port:** `25345`
- **Published Port:** `25345`
- **Protocol:** `TCP`

#### Environment Variables Tab
Add the following:
```
PYTHONUNBUFFERED=1
LOG_LEVEL=INFO
```

#### Restart Policy Tab
- **Restart Policy:** `unless-stopped`
- **Max Retry Count:** `5`

#### Health Check Tab
- **Enable Health Check:** `Yes`
- **Health Check Command:** `curl -f http://localhost:25345/health || exit 1`
- **Interval:** `30s`
- **Timeout:** `10s`
- **Retries:** `3`
- **Start Period:** `5s`

#### Volumes Tab
Add persistent logging volume:
- **Host Path:** `/var/log/tradingview-webhook`
- **Container Path:** `/app/logs`
- **Read Only:** `No`

### 5. Deploy Application

1. Click "Deploy" button
2. Monitor deployment progress
3. Check logs for any errors
4. Verify application is running

---

## Nginx Reverse Proxy

### 1. Install Nginx

```bash
# Install Nginx
sudo apt-get install -y nginx

# Enable Nginx service
sudo systemctl enable nginx
sudo systemctl start nginx

# Verify installation
sudo systemctl status nginx
```

### 2. Create Nginx Configuration

Create `/etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za`:

```bash
sudo nano /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za
```

Add the following configuration:

```nginx
# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ctrader.emmanuelshekinah.co.za;

    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all HTTP to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ctrader.emmanuelshekinah.co.za;

    # SSL certificates (will be created by Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Logging
    access_log /var/log/nginx/ctrader.access.log;
    error_log /var/log/nginx/ctrader.error.log;

    # Proxy settings
    client_max_body_size 10M;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Reverse proxy to FastAPI application
    location / {
        proxy_pass http://localhost:25345;
        proxy_http_version 1.1;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        
        # WebSocket support (if needed)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Health check endpoint (no logging)
    location /health {
        proxy_pass http://localhost:25345/health;
        access_log off;
    }
}
```

### 3. Enable Nginx Configuration

```bash
# Create symlink to enable site
sudo ln -s /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za \
  /etc/nginx/sites-enabled/

# Remove default site (optional)
sudo rm /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Expected output: syntax is ok, test is successful

# Reload Nginx
sudo systemctl reload nginx
```

### 4. Verify Nginx is Running

```bash
# Check status
sudo systemctl status nginx

# Check listening ports
sudo netstat -tlnp | grep nginx

# Expected output:
# tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      1234/nginx
# tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      1234/nginx
```

---

## HTTPS with Let's Encrypt

### 1. Install Certbot

```bash
# Install Certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Verify installation
certbot --version
```

### 2. Create Certificate

```bash
# Create certificate for your domain
sudo certbot certonly --webroot \
  -w /var/www/certbot \
  -d ctrader.emmanuelshekinah.co.za \
  --email your-email@example.com \
  --agree-tos \
  --non-interactive

# Expected output: Successfully received certificate
```

If webroot doesn't exist, create it:

```bash
sudo mkdir -p /var/www/certbot
sudo chown -R www-data:www-data /var/www/certbot
```

### 3. Verify Certificate

```bash
# List certificates
sudo certbot certificates

# Expected output:
# Certificate Name: ctrader.emmanuelshekinah.co.za
# Domains: ctrader.emmanuelshekinah.co.za
# Expiry Date: 2027-05-27
```

### 4. Setup Auto-Renewal

```bash
# Enable certbot renewal timer
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Test renewal (dry-run)
sudo certbot renew --dry-run

# Check renewal status
sudo systemctl status certbot.timer
```

### 5. Test HTTPS Access

```bash
# Test from command line
curl -I https://ctrader.emmanuelshekinah.co.za

# Expected output:
# HTTP/2 200
# server: nginx
# strict-transport-security: max-age=31536000; includeSubDomains
```

---

## Environment Variables

### 1. Set in Dokploy Dashboard

In Dokploy application settings, add environment variables:

```
PYTHONUNBUFFERED=1
LOG_LEVEL=INFO
ENVIRONMENT=production
```

### 2. Create .env File (Alternative)

Create `/opt/tradingview-webhook/.env`:

```bash
cat > /opt/tradingview-webhook/.env << EOF
PYTHONUNBUFFERED=1
LOG_LEVEL=INFO
ENVIRONMENT=production
EOF
```

### 3. Update Dockerfile to Use .env

Modify Dockerfile to include:

```dockerfile
# Copy environment file
COPY .env .env

# Load environment variables
ENV $(cat .env | xargs)
```

---

## Monitoring & Logs

### 1. View Application Logs

```bash
# View Dokploy logs
sudo journalctl -u dokploy -f

# View Docker container logs
docker logs -f tradingview-webhook

# View persistent logs
tail -f /var/log/tradingview-webhook/app.log
```

### 2. View Nginx Logs

```bash
# Access logs
tail -f /var/log/nginx/ctrader.access.log

# Error logs
tail -f /var/log/nginx/ctrader.error.log

# Real-time monitoring
watch -n 1 'tail -20 /var/log/nginx/ctrader.access.log'
```

### 3. Monitor Application Health

```bash
# Check application status
curl -I https://ctrader.emmanuelshekinah.co.za/health

# Expected output:
# HTTP/2 200
# content-type: application/json

# Get health details
curl https://ctrader.emmanuelshekinah.co.za/health

# Expected output:
# {"status":"healthy","timestamp":"2026-05-27T10:00:00Z","signal_stored":false}
```

### 4. Setup Log Rotation

Create `/etc/logrotate.d/tradingview-webhook`:

```bash
sudo nano /etc/logrotate.d/tradingview-webhook
```

Add:

```
/var/log/tradingview-webhook/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        systemctl reload dokploy > /dev/null 2>&1 || true
    endscript
}
```

### 5. Monitor System Resources

```bash
# Install monitoring tools
sudo apt-get install -y htop iotop

# Monitor CPU and memory
htop

# Monitor disk I/O
iotop

# Check disk usage
df -h

# Check memory usage
free -h
```

---

## Troubleshooting

### Issue 1: Application Not Accessible

**Symptoms:** `Connection refused` or `502 Bad Gateway`

**Solutions:**

```bash
# Check if application is running
docker ps | grep tradingview

# Check application logs
docker logs tradingview-webhook

# Check if port 25345 is listening
sudo netstat -tlnp | grep 25345

# Check firewall rules
sudo ufw status

# Test local connection
curl http://localhost:25345/health

# Check Nginx configuration
sudo nginx -t

# Restart application
docker restart tradingview-webhook
```

### Issue 2: HTTPS Certificate Issues

**Symptoms:** `SSL certificate problem` or `ERR_CERT_AUTHORITY_INVALID`

**Solutions:**

```bash
# Check certificate validity
sudo certbot certificates

# Renew certificate manually
sudo certbot renew --force-renewal

# Check certificate expiry
openssl x509 -in /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/fullchain.pem -noout -dates

# Verify certificate chain
openssl s_client -connect ctrader.emmanuelshekinah.co.za:443 -showcerts

# Reload Nginx after certificate update
sudo systemctl reload nginx
```

### Issue 3: High Memory Usage

**Symptoms:** Application consuming excessive memory

**Solutions:**

```bash
# Check memory usage
docker stats tradingview-webhook

# Check for memory leaks in logs
docker logs tradingview-webhook | grep -i memory

# Restart application
docker restart tradingview-webhook

# Limit memory in docker-compose.yml
# Add: mem_limit: 512m
```

### Issue 4: Slow Response Times

**Symptoms:** Requests taking too long

**Solutions:**

```bash
# Check application logs for errors
docker logs tradingview-webhook

# Monitor system resources
htop

# Check Nginx upstream response time
tail -f /var/log/nginx/ctrader.access.log | grep upstream_response_time

# Increase Nginx timeouts in configuration
# proxy_connect_timeout 120s;
# proxy_send_timeout 120s;
# proxy_read_timeout 120s;

# Reload Nginx
sudo systemctl reload nginx
```

### Issue 5: Firewall Blocking Traffic

**Symptoms:** `Connection timed out`

**Solutions:**

```bash
# Check UFW status
sudo ufw status verbose

# Check if ports are open
sudo ufw show added

# Test port connectivity
nc -zv ctrader.emmanuelshekinah.co.za 443

# Temporarily disable UFW for testing (not recommended for production)
sudo ufw disable

# Re-enable UFW
sudo ufw enable
```

### Issue 6: Domain Not Resolving

**Symptoms:** `Name or service not known`

**Solutions:**

```bash
# Check DNS resolution
nslookup ctrader.emmanuelshekinah.co.za

# Check DNS propagation
dig ctrader.emmanuelshekinah.co.za

# Flush DNS cache
sudo systemctl restart systemd-resolved

# Test from different DNS servers
nslookup ctrader.emmanuelshekinah.co.za 8.8.8.8
```

### Issue 7: Docker Container Won't Start

**Symptoms:** Container exits immediately

**Solutions:**

```bash
# Check container logs
docker logs tradingview-webhook

# Check Docker daemon status
sudo systemctl status docker

# Restart Docker daemon
sudo systemctl restart docker

# Check disk space
df -h

# Rebuild image
docker build -t tradingview-webhook-bridge .

# Run container manually for debugging
docker run -it --rm -p 25345:25345 tradingview-webhook-bridge
```

### Issue 8: Permission Denied Errors

**Symptoms:** `Permission denied` in logs

**Solutions:**

```bash
# Fix directory permissions
sudo chown -R $USER:$USER /opt/tradingview-webhook

# Fix log directory permissions
sudo mkdir -p /var/log/tradingview-webhook
sudo chown -R www-data:www-data /var/log/tradingview-webhook
sudo chmod 755 /var/log/tradingview-webhook

# Fix Nginx permissions
sudo chown -R www-data:www-data /var/www/certbot
```

---

## Quick Reference Commands

```bash
# Dokploy
sudo systemctl status dokploy
sudo systemctl restart dokploy
sudo journalctl -u dokploy -f

# Docker
docker ps
docker logs -f tradingview-webhook
docker restart tradingview-webhook
docker stats tradingview-webhook

# Nginx
sudo systemctl status nginx
sudo systemctl reload nginx
sudo nginx -t
tail -f /var/log/nginx/ctrader.access.log

# Certbot
sudo certbot certificates
sudo certbot renew --dry-run
sudo certbot renew --force-renewal

# UFW
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# System
df -h
free -h
htop
```

---

## Post-Deployment Checklist

- [ ] Application deployed in Dokploy
- [ ] Port 25345 accessible internally
- [ ] Firewall rules configured (UFW)
- [ ] Nginx reverse proxy configured
- [ ] HTTPS certificate installed
- [ ] Auto-renewal configured
- [ ] Domain resolves correctly
- [ ] HTTPS access working
- [ ] Health check endpoint responding
- [ ] Logs being written to persistent volume
- [ ] Log rotation configured
- [ ] Monitoring setup complete
- [ ] Backup strategy in place

---

## Support & Resources

- Dokploy Documentation: https://dokploy.com/docs
- Nginx Documentation: https://nginx.org/en/docs/
- Let's Encrypt: https://letsencrypt.org/
- Docker Documentation: https://docs.docker.com/
- Ubuntu Firewall: https://help.ubuntu.com/community/UFW

---

**Last Updated:** May 27, 2026
**Version:** 1.0.0
