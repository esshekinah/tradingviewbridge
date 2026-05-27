# cBot Quick Reference - TradingView Webhook Bridge

Fast reference guide for the cTrader cBot.

---

## 🚀 Quick Start (5 minutes)

### 1. Copy Code
```
Copy all code from: cTrader_WebhookBridge_cBot.cs
```

### 2. Paste in cTrader
```
Automate → New cBot → Paste code → Compile
```

### 3. Configure
```
Server IP: your-server-ip
Server Port: 25345
Volume: 0.1 lots
```

### 4. Start
```
Click Start → Select Live/Backtest → Start
```

---

## ⚙️ Configuration

### Minimum Setup
```
Server IP: localhost
Server Port: 25345
Volume: 0.1
```

### Production Setup
```
Server IP: ctrader.emmanuelshekinah.co.za
Server Port: 25345
Use HTTPS: true
Volume: 0.1
Stop Loss: 50 pips
Take Profit: 100 pips
Poll Interval: 5000 ms
```

---

## 📊 Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| Server IP | localhost | Your webhook server |
| Server Port | 25345 | Default webhook port |
| Use HTTPS | false | true for production |
| Volume | 0.1 | Trade size in lots |
| Stop Loss | 50 | In pips (0 = disabled) |
| Take Profit | 100 | In pips (0 = disabled) |
| Poll Interval | 5000 | In milliseconds |
| Enable Logging | true | Log to cTrader |

---

## 🔍 Testing

### Test Server Connection
```bash
curl http://SERVER_IP:25345/health
```

### Send Test Signal
```bash
curl -X POST http://SERVER_IP:25345/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"EURUSD","action":"BUY","price":"1.0850","time":"2026-05-27T10:00:00Z"}'
```

### Expected Log Output
```
[2026-05-27 10:00:00.000] === TradingView Webhook Bridge cBot Started ===
[2026-05-27 10:00:00.000] Server: localhost:25345
[2026-05-27 10:00:00.000] Robot initialized successfully
[2026-05-27 10:00:05.000] New signal received: EURUSD BUY @ 1.0850
[2026-05-27 10:00:05.000] ✓ Trade executed: Buy 0.1 EURUSD @ 1.0850
```

---

## 🐛 Troubleshooting

### Compilation Error
```
Solution: Add using Newtonsoft.Json;
```

### Connection Refused
```
Solution: Check server is running and IP is correct
```

### No Signals Received
```
Solution: Verify server is running and accessible
```

### Duplicate Signals
```
Solution: Built-in duplicate detection - should not happen
```

### Trades Not Executing
```
Solution: Check account balance, symbol availability, volume limits
```

---

## 📝 Log Messages

| Message | Status |
|---------|--------|
| `Robot initialized successfully` | ✓ OK |
| `New signal received` | ✓ OK |
| `Trade executed` | ✓ OK |
| `Duplicate signal ignored` | ℹ Info |
| `WARNING: HTTP request failed` | ⚠ Warning |
| `ERROR: Symbol not found` | ✗ Error |

---

## 🎯 Best Practices

1. **Start Small** - Use 0.01 lots for testing
2. **Test First** - Backtest before live trading
3. **Monitor Logs** - Check logs regularly
4. **Use Stop Loss** - Always set stop loss
5. **Verify Server** - Ensure webhook server is running
6. **Check Balance** - Verify account has funds
7. **Monitor Trades** - Watch for unexpected behavior

---

## 📋 Pre-Launch Checklist

- [ ] Code compiles without errors
- [ ] Server is running and accessible
- [ ] Test signal is received
- [ ] Trade executes correctly
- [ ] Duplicate detection works
- [ ] Error handling works
- [ ] Stop loss is set
- [ ] Volume is appropriate
- [ ] Logging is enabled
- [ ] Account has balance

---

## 🔗 Key Files

| File | Purpose |
|------|---------|
| `cTrader_WebhookBridge_cBot.cs` | Main cBot code |
| `CBOT_SETUP_GUIDE.md` | Detailed setup guide |
| `CBOT_QUICK_REFERENCE.md` | This file |

---

## 📞 Support

### cTrader
- Documentation: https://ctrader.com/algos/
- Forum: https://ctrader.com/forum/
- Support: https://support.ctrader.com/

### Webhook Bridge
- See `README.md` in webhook bridge package
- See `DOKPLOY_DEPLOYMENT.md` for server setup

---

## 💡 Tips

### Optimize Performance
- Increase poll interval if CPU is high
- Disable logging if not needed
- Use smaller volume for faster execution

### Improve Reliability
- Use HTTPS in production
- Monitor server health
- Check logs regularly
- Restart if needed

### Better Trading
- Start with small volume
- Test thoroughly
- Use appropriate stop loss/take profit
- Monitor account balance

---

## 🚀 Common Commands

### Start cBot
```
Click Start → Select Mode → Start
```

### Stop cBot
```
Click Stop
```

### View Logs
```
Check Output Panel in cTrader
```

### Test Server
```bash
curl http://SERVER_IP:25345/health
```

### Send Signal
```bash
curl -X POST http://SERVER_IP:25345/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"EURUSD","action":"BUY","price":"1.0850","time":"2026-05-27T10:00:00Z"}'
```

---

## 📊 Expected Performance

- **Response Time:** <1 second
- **CPU Usage:** <5%
- **Memory:** ~50-100 MB
- **Network:** <1 KB per poll

---

## ⚡ Quick Fixes

| Issue | Fix |
|-------|-----|
| Compilation error | Add `using Newtonsoft.Json;` |
| Connection refused | Check server IP and port |
| No signals | Verify server is running |
| High CPU | Increase poll interval |
| No trades | Check account balance |

---

**Version:** 1.0.0
**Status:** Production Ready
**Last Updated:** May 27, 2026
