# Dokploy Deployment Guide - WITH NGINX FIX

Complete guide to deploy TradingView Webhook Bridge on Dokploy with proper Nginx configuration for POST requests.

**Domain:** `ctrader.emmanuelshekinah.co.za`
**Port:** `25345` (internal), `80/443` (external via Nginx)
**Status:** ✅ Fixed - POST requests will work

---

## 🚀 Quick Deployment (Recommended)

### Use the Automated Deployment Script

```bash
# 1. SSH to VPS
ssh user@your-vps-ip

# 2. Download deployment script
curl -O https://raw.githubusercontent.com/your-repo/deploy-with-nginx-fix.sh

# 3. Make executable
chmod +x deploy-with-nginx-fix.sh

# 4. Run deployment
sudo bash deploy-with-nginx-fix.sh

# 5. Deploy application via Dokploy dashboard
# Access: http://<your-vps-ip>:3000
```

**What this script does:**
- ✅ Cleans up duplicate Nginx instances
- ✅ Configures Nginx properly for POST requests
- ✅ Enables Nginx site
- ✅ Tests Nginx configuration
- ✅ Starts Nginx
- ✅ Verifies deployment

---

## 📋 Manual Deployment Steps

If you prefer manual deployment:

### Step 1: Clean Up Nginx

```bash
# Stop all Nginx instances
sudo systemctl stop nginx
sudo killall nginx
sudo killall -9 nginx

# Remove duplicate configs
sudo rm /etc/nginx/sites-available/tradingview-webhook
sudo rm /etc/nginx/sites-enabled/tradingview-webhook
sudo rm /etc/nginx/sites-enabled/default

# Verify only your domain config remains
ls -la /etc/nginx/sites-enabled/
```

### Step 2: Create Nginx Configuration

```bash
sudo nano /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za
```

**Paste this configuration:**

```nginx
# HTTP server (port 80)
server {
    listen 80;
    listen [::]:80;
    server_name ctrader.emmanuelshekinah.co.za;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Root location - catches ALL requests
    location / {
        proxy_pass http://localhost:25345;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Content-Type $content_type;
        
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Webhook endpoint (POST)
    location /webhook {
        proxy_pass http://localhost:25345/webhook;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Content-Type $content_type;
        
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Signal endpoint (GET)
    location /signal {
        proxy_pass http://localhost:25345/signal;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health endpoint (GET)
    location /health {
        proxy_pass http://localhost:25345/health;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# HTTPS server (port 443)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ctrader.emmanuelshekinah.co.za;

    ssl_certificate /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        proxy_pass http://localhost:25345;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Content-Type $content_type;
        
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /webhook {
        proxy_pass http://localhost:25345/webhook;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Content-Type $content_type;
        
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    location /signal {
        proxy_pass http://localhost:25345/signal;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://localhost:25345/health;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Step 3: Enable Site

```bash
sudo ln -sf /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za \
  /etc/nginx/sites-enabled/ctrader.emmanuelshekinah.co.za
```

### Step 4: Test Nginx

```bash
sudo nginx -t
```

**Expected:** `syntax is ok`

### Step 5: Start Nginx

```bash
sudo systemctl start nginx
```

### Step 6: Deploy Application via Dokploy

1. Access Dokploy: `http://<your-vps-ip>:3000`
2. Create/update application
3. Deploy application
4. Wait for deployment to complete

### Step 7: Test Endpoints

```bash
# Health check
curl http://ctrader.emmanuelshekinah.co.za/health

# Get signal
curl http://ctrader.emmanuelshekinah.co.za/signal

# Send webhook (POST) - THIS WILL NOW WORK
curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'
```

---

## ✅ Verification

### Check Nginx Status
```bash
sudo systemctl status nginx
```

### Check Only One Nginx Running
```bash
ps aux | grep nginx
# Should show only ONE master process
```

### Check Listening Ports
```bash
sudo netstat -tlnp | grep nginx
# Should show port 80 and 443
```

### Test All Endpoints

```bash
# 1. Health
curl http://ctrader.emmanuelshekinah.co.za/health

# 2. Signal
curl http://ctrader.emmanuelshekinah.co.za/signal

# 3. Webhook (POST)
curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'

# 4. API Info
curl http://ctrader.emmanuelshekinah.co.za/
```

---

## 🔧 cBot Configuration

After deployment, configure your cBot:

```
Server IP/Domain: ctrader.emmanuelshekinah.co.za
Server Port: 80
Use HTTPS: false
```

Or use port 25345 directly:

```
Server IP/Domain: ctrader.emmanuelshekinah.co.za
Server Port: 25345
Use HTTPS: false
```

---

## 📊 Expected Results

### Health Check Response
```json
{
  "status": "healthy",
  "timestamp": "2026-05-27T10:00:00Z",
  "signal_stored": false
}
```

### Webhook Response
```json
{
  "status": "success",
  "message": "Alert received and stored",
  "symbol": "XAUUSD",
  "action": "SELL"
}
```

### Signal Response
```json
{
  "symbol": "XAUUSD",
  "action": "SELL",
  "price": "3345.12",
  "time": "2026-05-27T10:00:00Z",
  "received_at": "2026-05-27T10:00:05.123456Z"
}
```

---

## 🐛 Troubleshooting

### POST Still Not Working?

**Check Nginx logs:**
```bash
tail -f /var/log/nginx/error.log
```

**Check backend logs:**
```bash
docker logs tradingview-webhook-bridge
```

**Test local connection:**
```bash
curl -X POST http://localhost:25345/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'
```

### Nginx Won't Start?

```bash
# Check syntax
sudo nginx -t

# Check for port conflicts
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Kill any process on port 80
sudo fuser -k 80/tcp

# Try starting again
sudo systemctl start nginx
```

---

## 📚 Files Included

- **`nginx.conf`** - Nginx configuration file
- **`deploy-with-nginx-fix.sh`** - Automated deployment script
- **`DOKPLOY_DEPLOYMENT_FIXED.md`** - This guide

---

## ✅ Deployment Checklist

- [ ] Nginx cleaned up (no duplicates)
- [ ] Nginx configuration created
- [ ] Nginx site enabled
- [ ] Nginx configuration tested
- [ ] Nginx started
- [ ] Application deployed via Dokploy
- [ ] Health endpoint responding
- [ ] Signal endpoint responding
- [ ] Webhook endpoint responding (POST)
- [ ] cBot configured
- [ ] cBot connected and receiving signals

---

**Status:** ✅ Ready for Deployment
**Time:** ~10 minutes
**Difficulty:** Easy

**Ready? Use the automated script or follow manual steps above!** 🚀
