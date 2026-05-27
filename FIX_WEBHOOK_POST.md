# Fix: POST Webhook Returning 404

**Issue:** `curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook` returns "page not found"

**Cause:** Nginx configuration may not be properly routing POST requests to the FastAPI backend

**Solution:** Update Nginx configuration

---

## 🔧 Quick Fix

### Step 1: Update Nginx Configuration

```bash
# Backup current config
sudo cp /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za \
  /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za.backup

# Edit config
sudo nano /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za
```

### Step 2: Replace with Correct Configuration

Replace the entire file with the content from `nginx-ctrader-config.conf`

**Key changes:**
- ✅ Explicit `/webhook` location block
- ✅ Proper POST request handling
- ✅ Correct proxy headers
- ✅ Content-Type header set

### Step 3: Test Nginx Configuration

```bash
sudo nginx -t
```

**Expected output:**
```
nginx: the configuration file /etc/nginx/conf.d/nginx.conf syntax is ok
nginx: configuration will be successful
```

### Step 4: Reload Nginx

```bash
sudo systemctl reload nginx
```

### Step 5: Test Webhook

```bash
curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'
```

**Expected response:**
```json
{
  "status": "success",
  "message": "Alert received and stored",
  "symbol": "XAUUSD",
  "action": "SELL"
}
```

---

## 📋 Complete Configuration

### File: `/etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za`

```nginx
# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ctrader.emmanuelshekinah.co.za;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
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
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    access_log /var/log/nginx/ctrader.access.log;
    error_log /var/log/nginx/ctrader.error.log;

    client_max_body_size 10M;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Root endpoint - catches all requests
    location / {
        proxy_pass http://localhost:25345;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Explicit webhook endpoint for POST requests
    location /webhook {
        proxy_pass http://localhost:25345/webhook;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        proxy_set_header Content-Type "application/json";
        
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Signal endpoint
    location /signal {
        proxy_pass http://localhost:25345/signal;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health endpoint
    location /health {
        proxy_pass http://localhost:25345/health;
        access_log off;
    }
}
```

---

## ✅ Verification Steps

### 1. Check Nginx Configuration
```bash
sudo nginx -t
```

### 2. Check Nginx is Running
```bash
sudo systemctl status nginx
```

### 3. Check Backend is Running
```bash
docker ps | grep tradingview
```

### 4. Test Health Endpoint
```bash
curl https://ctrader.emmanuelshekinah.co.za/health
```

### 5. Test Webhook Endpoint
```bash
curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'
```

### 6. Verify Signal Stored
```bash
curl https://ctrader.emmanuelshekinah.co.za/signal
```

---

## 🐛 Troubleshooting

### Still Getting 404?

**Check Nginx logs:**
```bash
tail -f /var/log/nginx/ctrader.error.log
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

### Nginx Won't Reload?

```bash
# Check syntax
sudo nginx -t

# If error, check config file
sudo cat /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za

# Restart instead of reload
sudo systemctl restart nginx
```

### Backend Not Responding?

```bash
# Check if container is running
docker ps | grep tradingview

# Check container logs
docker logs tradingview-webhook-bridge

# Restart container
docker restart tradingview-webhook-bridge
```

---

## 📊 Expected Behavior

### Before Fix
```
$ curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook ...
page not found
```

### After Fix
```
$ curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'

{
  "status": "success",
  "message": "Alert received and stored",
  "symbol": "XAUUSD",
  "action": "SELL"
}
```

---

## 🔄 Complete Fix Procedure

### 1. SSH to VPS
```bash
ssh user@your-vps-ip
```

### 2. Backup Current Config
```bash
sudo cp /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za \
  /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za.backup
```

### 3. Edit Config
```bash
sudo nano /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za
```

### 4. Replace Content
Copy the complete configuration from above and paste it.

### 5. Test
```bash
sudo nginx -t
```

### 6. Reload
```bash
sudo systemctl reload nginx
```

### 7. Test Webhook
```bash
curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'
```

---

## ✅ Success Indicators

- ✅ `sudo nginx -t` returns "syntax is ok"
- ✅ `sudo systemctl status nginx` shows "active (running)"
- ✅ `curl https://ctrader.emmanuelshekinah.co.za/health` returns JSON
- ✅ `curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook ...` returns success
- ✅ `curl https://ctrader.emmanuelshekinah.co.za/signal` returns signal data

---

## 📝 Key Points

1. **Root location** catches all requests and proxies to FastAPI
2. **Explicit /webhook location** ensures POST requests are handled
3. **Proper headers** are set for all proxy requests
4. **Content-Type** is explicitly set for POST requests
5. **Buffering** is enabled for proper request/response handling

---

**Status:** Ready to fix
**Time to fix:** ~5 minutes
**Difficulty:** Easy

**Ready? Follow the Quick Fix steps above!** ✅
