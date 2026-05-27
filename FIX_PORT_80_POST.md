# Fix: Port 80 POST Requests Not Working

**Issue:** POST to `http://ctrader.emmanuelshekinah.co.za/webhook` returns 404
**But:** GET to `http://ctrader.emmanuelshekinah.co.za:25345/signal` works

**Cause:** Nginx on port 80 is not properly routing POST requests

---

## 🔧 Quick Fix (2 minutes)

### Step 1: SSH to VPS
```bash
ssh user@your-vps-ip
```

### Step 2: Backup Current Config
```bash
sudo cp /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za \
  /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za.backup
```

### Step 3: Edit Nginx Config
```bash
sudo nano /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za
```

### Step 4: Replace with This Configuration

```nginx
# HTTP server (port 80)
server {
    listen 80;
    listen [::]:80;
    server_name ctrader.emmanuelshekinah.co.za;

    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Root location - catches ALL requests (GET, POST, PUT, DELETE)
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
```

### Step 5: Test Nginx
```bash
sudo nginx -t
```

Expected: `syntax is ok`

### Step 6: Reload Nginx
```bash
sudo systemctl reload nginx
```

### Step 7: Test POST on Port 80
```bash
curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook \
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

## ✅ Test All Endpoints on Port 80

```bash
# Health check
curl http://ctrader.emmanuelshekinah.co.za/health

# Get signal
curl http://ctrader.emmanuelshekinah.co.za/signal

# Send webhook (POST)
curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'

# API info
curl http://ctrader.emmanuelshekinah.co.za/
```

---

## 🔧 Key Changes

**What was wrong:**
- ❌ Nginx wasn't routing POST requests properly
- ❌ Missing `Content-Type` header forwarding
- ❌ Missing explicit `/webhook` location block

**What's fixed:**
- ✅ Root location catches ALL HTTP methods
- ✅ Explicit `/webhook` location for POST
- ✅ `Content-Type` header properly forwarded
- ✅ Proper buffering for POST requests
- ✅ Correct timeouts set

---

## 📋 cBot Configuration

Now you can use port 80 in your cBot:

```
Server IP/Domain: ctrader.emmanuelshekinah.co.za
Server Port: 80
Use HTTPS: false
```

Or stick with port 25345:

```
Server IP/Domain: ctrader.emmanuelshekinah.co.za
Server Port: 25345
Use HTTPS: false
```

---

## 🧪 Verification

### Before Fix
```bash
$ curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook ...
page not found
```

### After Fix
```bash
$ curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook ...
{
  "status": "success",
  "message": "Alert received and stored",
  "symbol": "XAUUSD",
  "action": "SELL"
}
```

---

## 🐛 Troubleshooting

### Still Getting 404?

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

### Nginx Won't Reload?

```bash
# Check syntax
sudo nginx -t

# If error, restart instead
sudo systemctl restart nginx
```

---

## ✅ Success Indicators

- ✅ `sudo nginx -t` returns "syntax is ok"
- ✅ `sudo systemctl status nginx` shows "active (running)"
- ✅ `curl http://ctrader.emmanuelshekinah.co.za/health` returns JSON
- ✅ `curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook ...` returns success
- ✅ `curl http://ctrader.emmanuelshekinah.co.za/signal` returns signal data

---

## 📝 Summary

**Problem:** Port 80 POST requests not working
**Solution:** Update Nginx configuration to properly route POST requests
**Time:** 2 minutes
**Result:** All endpoints work on port 80

---

**Ready? Follow the 7 steps above!** ✅
