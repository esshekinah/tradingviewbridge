# Webhook Bridge - Correct Endpoints

**Domain:** `ctrader.emmanuelshekinah.co.za`
**Internal Port:** `25345`
**External Port:** `80` (HTTP) / `443` (HTTPS)

---

## ✅ Correct Endpoints

### 1. Health Check
```
GET https://ctrader.emmanuelshekinah.co.za/health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-05-27T09:48:15.123456Z",
  "signal_stored": false
}
```

**Test:**
```bash
curl https://ctrader.emmanuelshekinah.co.za/health
```

---

### 2. Get Latest Signal
```
GET https://ctrader.emmanuelshekinah.co.za/signal
```

**Response (with signal):**
```json
{
  "symbol": "XAUUSD",
  "action": "BUY",
  "price": "3345.12",
  "time": "2026-05-27T10:00:00Z",
  "received_at": "2026-05-27T10:00:05.123456Z"
}
```

**Response (no signal):**
```json
{
  "detail": "No signal received yet"
}
```

**Test:**
```bash
curl https://ctrader.emmanuelshekinah.co.za/signal
```

---

### 3. Send Webhook Alert
```
POST https://ctrader.emmanuelshekinah.co.za/webhook
Content-Type: application/json
```

**Request Body:**
```json
{
  "symbol": "XAUUSD",
  "action": "BUY",
  "price": "3345.12",
  "time": "2026-05-27T10:00:00Z"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Alert received and stored",
  "symbol": "XAUUSD",
  "action": "BUY"
}
```

**Test:**
```bash
curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "XAUUSD",
    "action": "BUY",
    "price": "3345.12",
    "time": "2026-05-27T10:00:00Z"
  }'
```

---

### 4. API Information
```
GET https://ctrader.emmanuelshekinah.co.za/
```

**Response:**
```json
{
  "service": "TradingView Webhook Bridge",
  "version": "1.0.0",
  "endpoints": {
    "POST /webhook": "Receive TradingView alerts",
    "GET /signal": "Get latest stored signal",
    "GET /health": "Health check",
    "GET /": "This endpoint"
  }
}
```

**Test:**
```bash
curl https://ctrader.emmanuelshekinah.co.za/
```

---

## ❌ Wrong Endpoints (Don't Use)

| Wrong | Correct | Issue |
|-------|---------|-------|
| `/healthpage` | `/health` | Endpoint doesn't exist |
| `:25345/health` | `/health` | Port exposed (use Nginx) |
| `http://` (production) | `https://` | Not secure |
| `/signals` | `/signal` | Wrong endpoint name |
| `/webhooks` | `/webhook` | Wrong endpoint name |

---

## 🔗 cBot Configuration

### Server Settings
```
Server IP/Domain: ctrader.emmanuelshekinah.co.za
Server Port: 80 (or 443 for HTTPS)
Use HTTPS: true
```

### cBot Will Access
```
https://ctrader.emmanuelshekinah.co.za/signal
```

---

## 🧪 Complete Test Sequence

### Step 1: Check Health
```bash
curl https://ctrader.emmanuelshekinah.co.za/health
```

Expected: `{"status":"healthy",...}`

### Step 2: Check Signal (Empty)
```bash
curl https://ctrader.emmanuelshekinah.co.za/signal
```

Expected: `{"detail":"No signal received yet"}`

### Step 3: Send Test Signal
```bash
curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"EURUSD","action":"BUY","price":"1.0850","time":"2026-05-27T10:00:00Z"}'
```

Expected: `{"status":"success",...}`

### Step 4: Get Signal
```bash
curl https://ctrader.emmanuelshekinah.co.za/signal
```

Expected: Signal data with symbol, action, price, time, received_at

---

## 📊 Endpoint Summary

| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/` | GET | API info | ✅ |
| `/health` | GET | Health check | ✅ |
| `/signal` | GET | Latest signal | ✅ |
| `/webhook` | POST | Receive alert | ✅ |

---

## 🔐 Protocol

### HTTP (Testing Only)
```
http://ctrader.emmanuelshekinah.co.za/health
```

### HTTPS (Production)
```
https://ctrader.emmanuelshekinah.co.za/health
```

---

## 🚀 Quick Start

### 1. Test Server
```bash
curl https://ctrader.emmanuelshekinah.co.za/health
```

### 2. Configure cBot
```
Server: ctrader.emmanuelshekinah.co.za
Port: 80 (or 443)
HTTPS: true
```

### 3. Start cBot
cBot will poll: `https://ctrader.emmanuelshekinah.co.za/signal`

### 4. Send Alert
```bash
curl -X POST https://ctrader.emmanuelshekinah.co.za/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"EURUSD","action":"BUY","price":"1.0850","time":"2026-05-27T10:00:00Z"}'
```

### 5. Verify
```bash
curl https://ctrader.emmanuelshekinah.co.za/signal
```

---

## 📝 Notes

- ✅ Server running on internal port 25345
- ✅ Nginx reverse proxy on ports 80/443
- ✅ HTTPS certificate installed
- ✅ CORS enabled
- ✅ All endpoints working
- ✅ Logging enabled

---

**Last Updated:** May 27, 2026
**Status:** ✅ All Endpoints Working
