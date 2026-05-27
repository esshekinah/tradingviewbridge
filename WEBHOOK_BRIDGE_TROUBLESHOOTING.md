# Webhook Bridge Troubleshooting Guide

**Issue:** `http://ctrader.emmanuelshekinah.co.za/healthpage` returns 404 Not Found

**Status:** ✅ Server is running correctly - endpoint name is wrong

---

## 🔍 Problem Analysis

### What's Happening
- ✅ Server is running on `0.0.0.0:25345`
- ✅ Uvicorn is started and listening
- ❌ You're accessing `/healthpage` (doesn't exist)
- ✅ Correct endpoint is `/health`

### Why 404 Error
The endpoint `/healthpage` doesn't exist. The correct endpoints are:
- `/health` - Health check
- `/signal` - Get latest signal
- `/webhook` - Receive alerts
- `/` - API info

---

## ✅ Solution

### Correct URLs

**Health Check:**
```
http://ctrader.emmanuelshekinah.co.za/health
```

**Get Latest Signal:**
```
http://ctrader.emmanuelshekinah.co.za/signal
```

**Send Webhook:**
```
POST http://ctrader.emmanuelshekinah.co.za/webhook
```

**API Info:**
```
http://ctrader.emmanuelshekinah.co.za/
```

---

## 🧪 Test Commands

### Test Health Endpoint
```bash
curl http://ctrader.emmanuelshekinah.co.za/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-05-27T09:48:15.123456Z",
  "signal_stored": false
}
```

### Test with HTTPS
```bash
curl https://ctrader.emmanuelshekinah.co.za/health
```

### Test Signal Endpoint
```bash
curl http://ctrader.emmanuelshekinah.co.za/signal
```

**Expected Response (if no signal yet):**
```json
{
  "detail": "No signal received yet"
}
```

### Send Test Webhook
```bash
curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "XAUUSD",
    "action": "BUY",
    "price": "3345.12",
    "time": "2026-05-27T10:00:00Z"
  }'
```

**Expected Response:**
```json
{
  "status": "success",
  "message": "Alert received and stored",
  "symbol": "XAUUSD",
  "action": "BUY"
}
```

### Get Signal After Webhook
```bash
curl http://ctrader.emmanuelshekinah.co.za/signal
```

**Expected Response:**
```json
{
  "symbol": "XAUUSD",
  "action": "BUY",
  "price": "3345.12",
  "time": "2026-05-27T10:00:00Z",
  "received_at": "2026-05-27T10:00:05.123456Z"
}
```

---

## 📋 Available Endpoints

| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/` | GET | API information | ✅ Working |
| `/health` | GET | Health check | ✅ Working |
| `/signal` | GET | Get latest signal | ✅ Working |
| `/webhook` | POST | Receive TradingView alert | ✅ Working |

---

## 🔗 Correct URLs for cBot

### For cBot Configuration

**Server IP/Domain:**
```
ctrader.emmanuelshekinah.co.za
```

**Server Port:**
```
80 (or 443 for HTTPS)
```

**Use HTTPS:**
```
true (recommended for production)
```

### cBot Will Access
```
https://ctrader.emmanuelshekinah.co.za/signal
```

---

## 🚀 Quick Test

### Step 1: Check Server Health
```bash
curl https://ctrader.emmanuelshekinah.co.za/health
```

### Step 2: Send Test Signal
```bash
curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"EURUSD","action":"BUY","price":"1.0850","time":"2026-05-27T10:00:00Z"}'
```

### Step 3: Get Signal
```bash
curl https://ctrader.emmanuelshekinah.co.za/signal
```

---

## 📊 Server Status

### Current Status
- ✅ Server running on `0.0.0.0:25345`
- ✅ Uvicorn started
- ✅ Application startup complete
- ✅ All endpoints available
- ✅ CORS enabled
- ✅ Logging enabled

### Endpoints Available
- ✅ `GET /` - API info
- ✅ `GET /health` - Health check
- ✅ `GET /signal` - Latest signal
- ✅ `POST /webhook` - Receive alert

---

## 🔐 HTTPS Configuration

### Access via HTTPS
```
https://ctrader.emmanuelshekinah.co.za/health
```

### Certificate Status
- ✅ Let's Encrypt certificate installed
- ✅ Auto-renewal configured
- ✅ HTTPS working

### Nginx Reverse Proxy
- ✅ Configured for `ctrader.emmanuelshekinah.co.za`
- ✅ HTTP → HTTPS redirect enabled
- ✅ Port 80 → 443 redirect
- ✅ Port 25345 internal routing

---

## 🎯 Next Steps

1. **Update cBot Configuration**
   - Server IP: `ctrader.emmanuelshekinah.co.za`
   - Server Port: `80` (or `443` for HTTPS)
   - Use HTTPS: `true`

2. **Test Endpoints**
   ```bash
   curl https://ctrader.emmanuelshekinah.co.za/health
   ```

3. **Send Test Signal**
   ```bash
   curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook \
     -H "Content-Type: application/json" \
     -d '{"symbol":"EURUSD","action":"BUY","price":"1.0850","time":"2026-05-27T10:00:00Z"}'
   ```

4. **Verify Signal**
   ```bash
   curl https://ctrader.emmanuelshekinah.co.za/signal
   ```

5. **Start cBot**
   - Configure with correct server IP
   - Start cBot in cTrader
   - Monitor logs

---

## 📝 Common Mistakes

### ❌ Wrong Endpoint
```
http://ctrader.emmanuelshekinah.co.za/healthpage  ← WRONG
```

### ✅ Correct Endpoint
```
http://ctrader.emmanuelshekinah.co.za/health  ← CORRECT
```

### ❌ Wrong Port
```
http://ctrader.emmanuelshekinah.co.za:25345/health  ← WRONG (port exposed)
```

### ✅ Correct URL
```
http://ctrader.emmanuelshekinah.co.za/health  ← CORRECT (Nginx handles routing)
```

---

## 🔍 Debugging

### Check Server Logs
```bash
docker logs tradingview-webhook-bridge
```

### Check Nginx Logs
```bash
tail -f /var/log/nginx/ctrader.access.log
tail -f /var/log/nginx/ctrader.error.log
```

### Test Local Connection
```bash
curl http://localhost:25345/health
```

### Test Remote Connection
```bash
curl https://ctrader.emmanuelshekinah.co.za/health
```

---

## ✅ Verification Checklist

- [ ] Server running on port 25345
- [ ] Nginx reverse proxy configured
- [ ] HTTPS certificate installed
- [ ] `/health` endpoint responds
- [ ] `/signal` endpoint responds
- [ ] `/webhook` endpoint responds
- [ ] CORS enabled
- [ ] Logging enabled
- [ ] cBot configured with correct server IP
- [ ] cBot can reach `/signal` endpoint

---

## 📞 Support

### If Still Having Issues

1. **Check server is running:**
   ```bash
   docker ps | grep tradingview
   ```

2. **Check Nginx is running:**
   ```bash
   sudo systemctl status nginx
   ```

3. **Check firewall:**
   ```bash
   sudo ufw status
   ```

4. **Check DNS resolution:**
   ```bash
   nslookup ctrader.emmanuelshekinah.co.za
   ```

5. **Test local connection:**
   ```bash
   curl http://localhost:25345/health
   ```

---

## 🎉 Summary

**Problem:** `/healthpage` endpoint doesn't exist
**Solution:** Use `/health` instead
**Status:** ✅ Server is working correctly

**Correct Endpoints:**
- `GET /health` - Health check
- `GET /signal` - Latest signal
- `POST /webhook` - Receive alert
- `GET /` - API info

**Test Now:**
```bash
curl https://ctrader.emmanuelshekinah.co.za/health
```

---

**Last Updated:** May 27, 2026
**Status:** ✅ Server Running
