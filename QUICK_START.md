# Quick Start - Dokploy Deployment

Fast-track deployment guide for TradingView Webhook Bridge on Dokploy.

## Prerequisites

- Ubuntu 20.04+ VPS
- Domain: `ctrader.emmanuelshekinah.co.za` (pointing to your VPS IP)
- SSH access to VPS
- Sudo privileges

## Step 1: Connect to Your VPS

```bash
ssh user@your-vps-ip
```

## Step 2: Download and Run Setup Script

```bash
# Download the setup script
curl -O https://raw.githubusercontent.com/your-repo/setup-dokploy.sh

# Make it executable
chmod +x setup-dokploy.sh

# Run with sudo (this will take 5-10 minutes)
sudo bash setup-dokploy.sh
```

**What this script does:**
- Updates system packages
- Installs Docker and Docker Compose
- Installs Dokploy
- Configures UFW firewall
- Installs Nginx
- Configures reverse proxy
- Installs Certbot
- Creates SSL certificate
- Sets up auto-renewal
- Configures log rotation

## Step 3: Upload Application Files

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

## Step 4: Access Dokploy Dashboard

1. Open browser: `http://<your-vps-ip>:3000`
2. Complete initial setup
3. Create admin account

## Step 5: Create Project in Dokploy

1. Click "Projects" → "Create Project"
2. Name: `TradingView Webhook Bridge`
3. Click "Create"

## Step 6: Create Application in Dokploy

1. Click on your project
2. Click "Create Application"
3. Select "Docker" deployment type
4. Fill in details:
   - **Name:** `tradingview-webhook`
   - **Description:** `cTrader webhook bridge`

## Step 7: Configure Docker Settings

### General Tab
- Name: `tradingview-webhook`

### Docker Tab
- Dockerfile Path: `./Dockerfile`
- Build Context: `/opt/tradingview-webhook`

### Ports Tab
- Container Port: `25345`
- Published Port: `25345`
- Protocol: `TCP`

### Environment Variables Tab
```
PYTHONUNBUFFERED=1
LOG_LEVEL=INFO
ENVIRONMENT=production
```

### Restart Policy Tab
- Restart Policy: `unless-stopped`
- Max Retry Count: `5`

### Health Check Tab
- Enable: `Yes`
- Command: `curl -f http://localhost:25345/health || exit 1`
- Interval: `30s`
- Timeout: `10s`
- Retries: `3`
- Start Period: `5s`

### Volumes Tab
- Host Path: `/var/log/tradingview-webhook`
- Container Path: `/app/logs`
- Read Only: `No`

## Step 8: Deploy Application

1. Click "Deploy" button
2. Monitor deployment progress
3. Check logs for errors

## Step 9: Verify Deployment

```bash
# Check application is running
curl -I https://ctrader.emmanuelshekinah.co.za/health

# Expected response:
# HTTP/2 200
# content-type: application/json

# Get health details
curl https://ctrader.emmanuelshekinah.co.za/health

# Test webhook endpoint
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
```

## Step 10: Configure TradingView

In TradingView alert settings, set webhook URL to:

```
https://ctrader.emmanuelshekinah.co.za/webhook
```

## Monitoring

### View Application Logs

```bash
# Docker logs
docker logs -f tradingview-webhook

# Persistent logs
tail -f /var/log/tradingview-webhook/app.log
```

### View Nginx Logs

```bash
# Access logs
tail -f /var/log/nginx/ctrader.access.log

# Error logs
tail -f /var/log/nginx/ctrader.error.log
```

### Check Application Status

```bash
# Docker status
docker ps | grep tradingview

# Health check
curl https://ctrader.emmanuelshekinah.co.za/health
```

## Common Commands

```bash
# Restart application
docker restart tradingview-webhook

# View Dokploy logs
sudo journalctl -u dokploy -f

# Check certificate
sudo certbot certificates

# Renew certificate (manual)
sudo certbot renew --force-renewal

# Check firewall
sudo ufw status

# View system resources
htop
```

## Troubleshooting

### Application not accessible

```bash
# Check if running
docker ps | grep tradingview

# Check logs
docker logs tradingview-webhook

# Check port listening
sudo netstat -tlnp | grep 25345

# Test local connection
curl http://localhost:25345/health
```

### HTTPS not working

```bash
# Check certificate
sudo certbot certificates

# Verify Nginx config
sudo nginx -t

# Check Nginx logs
tail -f /var/log/nginx/ctrader.error.log

# Reload Nginx
sudo systemctl reload nginx
```

### High memory usage

```bash
# Check memory
docker stats tradingview-webhook

# Restart container
docker restart tradingview-webhook
```

### Firewall blocking traffic

```bash
# Check UFW status
sudo ufw status

# Allow port if needed
sudo ufw allow 25345/tcp

# Reload UFW
sudo ufw reload
```

## Support

For detailed information, see:
- `DOKPLOY_DEPLOYMENT.md` - Complete deployment guide
- `README.md` - Application documentation
- Dokploy Docs: https://dokploy.com/docs

---

**Deployment Time:** ~10 minutes
**Difficulty:** Beginner-friendly
**Last Updated:** May 27, 2026
