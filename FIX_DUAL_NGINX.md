# Fix: Two Nginx Instances Conflict

**Issue:** POST on port 80 not working because two Nginx instances are running

**Solution:** Remove the duplicate Nginx and keep only one

---

## 🔍 Identify the Two Nginx Instances

### Check Running Nginx Processes
```bash
ps aux | grep nginx
```

**You'll see something like:**
```
root      1234  0.0  0.1  12345  6789 ?  Ss  10:00  0:00 nginx: master process
www-data  1235  0.0  0.2  23456  7890 ?  S   10:00  0:00 nginx: worker process
root      5678  0.0  0.1  12345  6789 ?  Ss  10:05  0:00 nginx: master process
www-data  5679  0.0  0.2  23456  7890 ?  S   10:05  0:00 nginx: worker process
```

### Check Nginx Config Files
```bash
# Check main nginx config
cat /etc/nginx/nginx.conf

# Check sites-available
ls -la /etc/nginx/sites-available/

# Check sites-enabled
ls -la /etc/nginx/sites-enabled/
```

---

## 🔧 Solution: Keep Only One Nginx

### Step 1: Stop All Nginx Instances
```bash
sudo systemctl stop nginx
sudo killall nginx
sudo killall -9 nginx
```

### Step 2: Verify All Stopped
```bash
ps aux | grep nginx
# Should show nothing (except the grep command itself)
```

### Step 3: Check for Duplicate Configs

**Look for duplicate site configs:**
```bash
ls -la /etc/nginx/sites-available/
```

**You might see:**
- `ctrader.emmanuelshekinah.co.za`
- `ctrader.emmanuelshekinah.co.za.backup`
- `tradingview-webhook`
- `default`

### Step 4: Remove Duplicates

**Keep only ONE config for your domain:**
```bash
# Remove duplicates
sudo rm /etc/nginx/sites-available/tradingview-webhook
sudo rm /etc/nginx/sites-enabled/tradingview-webhook

# Remove default if not needed
sudo rm /etc/nginx/sites-enabled/default

# Verify only your domain config remains
ls -la /etc/nginx/sites-enabled/
```

**Should show only:**
```
ctrader.emmanuelshekinah.co.za -> ../sites-available/ctrader.emmanuelshekinah.co.za
```

### Step 5: Verify Main Config

```bash
cat /etc/nginx/nginx.conf
```

**Should have:**
```nginx
http {
    include /etc/nginx/sites-enabled/*;
}
```

### Step 6: Update Your Domain Config

**Edit the main config:**
```bash
sudo nano /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za
```

**Replace with this complete config:**

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

# HTTPS server (port 443) - if you have SSL
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

    # Root location
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

    # Webhook endpoint
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
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Step 7: Test Nginx Configuration
```bash
sudo nginx -t
```

**Expected:**
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration will be successful
```

### Step 8: Start Nginx
```bash
sudo systemctl start nginx
```

### Step 9: Verify Only One Nginx Running
```bash
ps aux | grep nginx
```

**Should show only ONE master process and worker processes**

### Step 10: Test All Endpoints

```bash
# Health check
curl http://ctrader.emmanuelshekinah.co.za/health

# Get signal
curl http://ctrader.emmanuelshekinah.co.za/signal

# Send webhook (POST) - THIS SHOULD NOW WORK
curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'
```

---

## ✅ Expected Result

**After fix:**
```bash
$ curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook \
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

## 🔍 Verify Single Nginx

### Check Nginx Status
```bash
sudo systemctl status nginx
```

### Check Nginx Processes
```bash
ps aux | grep nginx
```

**Should show:**
```
root      1234  0.0  0.1  12345  6789 ?  Ss  10:00  0:00 nginx: master process
www-data  1235  0.0  0.2  23456  7890 ?  S   10:00  0:00 nginx: worker process
```

### Check Listening Ports
```bash
sudo netstat -tlnp | grep nginx
```

**Should show:**
```
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      1234/nginx
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      1234/nginx
```

---

## 🐛 Troubleshooting

### Still Not Working?

**Check Nginx error log:**
```bash
tail -f /var/log/nginx/error.log
```

**Check backend is running:**
```bash
docker ps | grep tradingview
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

# Kill any process on port 443
sudo fuser -k 443/tcp

# Try starting again
sudo systemctl start nginx
```

---

## 📋 Complete Cleanup Procedure

```bash
# 1. Stop all Nginx
sudo systemctl stop nginx
sudo killall nginx
sudo killall -9 nginx

# 2. Remove duplicate configs
sudo rm /etc/nginx/sites-available/tradingview-webhook
sudo rm /etc/nginx/sites-enabled/tradingview-webhook
sudo rm /etc/nginx/sites-enabled/default

# 3. Verify only one config
ls -la /etc/nginx/sites-enabled/

# 4. Update main config (see Step 6 above)
sudo nano /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za

# 5. Test
sudo nginx -t

# 6. Start
sudo systemctl start nginx

# 7. Verify
ps aux | grep nginx
sudo netstat -tlnp | grep nginx

# 8. Test endpoints
curl http://ctrader.emmanuelshekinah.co.za/health
curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'
```

---

## ✅ Success Checklist

- [ ] Only ONE Nginx master process running
- [ ] Only ONE config in `/etc/nginx/sites-enabled/`
- [ ] `sudo nginx -t` returns "syntax is ok"
- [ ] `curl http://ctrader.emmanuelshekinah.co.za/health` works
- [ ] `curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook ...` works
- [ ] `curl http://ctrader.emmanuelshekinah.co.za/signal` works

---

**Time to fix:** ~5 minutes
**Difficulty:** Easy

**Ready? Follow the 10 steps above!** ✅
