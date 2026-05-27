# cTrader cBot Setup Guide - TradingView Webhook Bridge

Complete guide to set up and configure the TradingView Webhook Bridge cBot in cTrader.

**cBot Name:** TradingView Webhook Bridge
**Language:** C#
**Framework:** cAlgo.API
**Status:** Production Ready

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Testing](#testing)
5. [Troubleshooting](#troubleshooting)
6. [Best Practices](#best-practices)

---

## Prerequisites

### System Requirements
- cTrader Desktop or Web Platform
- .NET Framework 4.5+
- Internet connection to webhook bridge server
- Valid cTrader account with trading permissions

### Required Libraries
- Newtonsoft.Json (JSON.NET) - Usually pre-installed in cTrader
- System.Net.Http - Built-in .NET library

### Webhook Bridge Server
- Python webhook bridge running and accessible
- Server IP/domain known
- Port 25345 accessible (or custom port)
- HTTPS certificate (if using HTTPS)

---

## Installation

### Step 1: Access cTrader cBot Editor

**Desktop Version:**
1. Open cTrader
2. Click "Automate" in the top menu
3. Click "New cBot"
4. Select "C#" as language

**Web Version:**
1. Open cTrader Web
2. Click "Automate" → "cBots"
3. Click "New cBot"
4. Select "C#" as language

### Step 2: Copy cBot Code

1. Open `cTrader_WebhookBridge_cBot.cs`
2. Copy all code
3. Paste into cTrader cBot editor
4. Replace any existing code

### Step 3: Compile

1. Click "Compile" button
2. Wait for compilation to complete
3. Check for any errors in the output panel

**Expected Output:**
```
Compilation successful
```

If you see errors:
- Check that Newtonsoft.Json is available
- Verify all namespaces are correct
- See Troubleshooting section

### Step 4: Save cBot

1. Click "Save" button
2. Enter cBot name: `TradingViewWebhookBridge`
3. Click "Save"

---

## Configuration

### Step 1: Set Server Connection

In cTrader cBot parameters:

**Server IP/Domain**
- Enter your webhook bridge server IP or domain
- Examples:
  - `192.168.1.100` (local network)
  - `ctrader.emmanuelshekinah.co.za` (domain)
  - `your-vps-ip` (VPS)

**Server Port**
- Default: `25345`
- Change only if using custom port

**Use HTTPS**
- Set to `false` for local/testing
- Set to `true` for production with valid SSL certificate

### Step 2: Set Trading Parameters

**Volume (Lots)**
- Default: `0.1`
- Adjust based on your account size
- Minimum: `0.01`

**Stop Loss (pips)**
- Default: `50`
- Set to `0` to disable
- Recommended: 30-100 pips

**Take Profit (pips)**
- Default: `100`
- Set to `0` to disable
- Recommended: 50-200 pips

### Step 3: Set Polling Parameters

**Poll Interval (ms)**
- Default: `5000` (5 seconds)
- Minimum: `1000` (1 second)
- Maximum: `60000` (1 minute)
- Lower values = more frequent checks (higher CPU usage)
- Higher values = less frequent checks (may miss signals)

**Enable Logging**
- Default: `true`
- Set to `false` to reduce log output

### Step 4: Example Configuration

For production trading:
```
Server IP/Domain: ctrader.emmanuelshekinah.co.za
Server Port: 25345
Use HTTPS: true
Volume: 0.1 lots
Stop Loss: 50 pips
Take Profit: 100 pips
Poll Interval: 5000 ms
Enable Logging: true
```

For testing:
```
Server IP/Domain: localhost
Server Port: 25345
Use HTTPS: false
Volume: 0.01 lots
Stop Loss: 50 pips
Take Profit: 100 pips
Poll Interval: 5000 ms
Enable Logging: true
```

---

## Testing

### Step 1: Start cBot in Backtest Mode

1. Click "Start" button
2. Select "Backtest" mode
3. Choose symbol and timeframe
4. Click "Start"

**Expected Output:**
```
[2026-05-27 10:00:00.000] === TradingView Webhook Bridge cBot Started ===
[2026-05-27 10:00:00.000] Server: localhost:25345
[2026-05-27 10:00:00.000] Protocol: HTTP
[2026-05-27 10:00:00.000] Poll Interval: 5000ms
[2026-05-27 10:00:00.000] Volume: 0.1 lots
[2026-05-27 10:00:00.000] Robot initialized successfully
```

### Step 2: Test Webhook Connection

1. Ensure webhook bridge server is running
2. Test server connectivity:
   ```bash
   curl http://SERVER_IP:25345/health
   ```

3. Expected response:
   ```json
   {
     "status": "healthy",
     "timestamp": "2026-05-27T10:00:00Z",
     "signal_stored": false
   }
   ```

### Step 3: Send Test Signal

From command line:
```bash
curl -X POST http://SERVER_IP:25345/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "EURUSD",
    "action": "BUY",
    "price": "1.0850",
    "time": "2026-05-27T10:00:00Z"
  }'
```

### Step 4: Monitor cBot Logs

In cTrader cBot output panel, you should see:
```
[2026-05-27 10:00:05.000] New signal received: EURUSD BUY @ 1.0850
[2026-05-27 10:00:05.000] ✓ Trade executed: Buy 0.1 EURUSD @ 1.0850
[2026-05-27 10:00:05.000]   Signal: EURUSD BUY @ 1.0850
[2026-05-27 10:00:05.000]   Stop Loss: 1.0800
[2026-05-27 10:00:05.000]   Take Profit: 1.0950
```

### Step 5: Test Duplicate Detection

Send the same signal twice:
```bash
# First signal
curl -X POST http://SERVER_IP:25345/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol": "EURUSD", "action": "BUY", "price": "1.0850", "time": "2026-05-27T10:00:00Z"}'

# Second signal (same)
curl -X POST http://SERVER_IP:25345/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol": "EURUSD", "action": "BUY", "price": "1.0850", "time": "2026-05-27T10:00:00Z"}'
```

Expected output:
```
[2026-05-27 10:00:05.000] New signal received: EURUSD BUY @ 1.0850
[2026-05-27 10:00:05.000] ✓ Trade executed: Buy 0.1 EURUSD @ 1.0850
[2026-05-27 10:00:10.000] Duplicate signal ignored: EURUSD BUY
```

### Step 6: Test Error Handling

Test with invalid symbol:
```bash
curl -X POST http://SERVER_IP:25345/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol": "INVALID", "action": "BUY", "price": "1.0850", "time": "2026-05-27T10:00:00Z"}'
```

Expected output:
```
[2026-05-27 10:00:05.000] New signal received: INVALID BUY @ 1.0850
[2026-05-27 10:00:05.000] ERROR: Symbol not found - INVALID
```

---

## Troubleshooting

### Issue 1: Compilation Errors

**Error:** `The type or namespace name 'JsonProperty' could not be found`

**Solution:**
1. Ensure Newtonsoft.Json is available
2. Add using statement: `using Newtonsoft.Json;`
3. Recompile

**Error:** `The type or namespace name 'HttpClient' could not be found`

**Solution:**
1. Add using statement: `using System.Net.Http;`
2. Recompile

### Issue 2: Connection Refused

**Error:** `Unable to connect to the remote server`

**Solution:**
1. Verify webhook bridge server is running
2. Check server IP/domain is correct
3. Verify port 25345 is accessible
4. Check firewall rules
5. Test connectivity: `ping SERVER_IP`

### Issue 3: No Signals Received

**Symptoms:** cBot running but no signals received

**Solutions:**
1. Verify webhook bridge server is running
2. Check server health: `curl http://SERVER_IP:25345/health`
3. Send test signal manually
4. Check cBot logs for errors
5. Verify poll interval is not too long
6. Check network connectivity

### Issue 4: Duplicate Signals

**Symptoms:** Same signal executed multiple times

**Solution:**
- Duplicate detection is built-in
- If still occurring, check webhook bridge server
- Verify signal is being updated on server

### Issue 5: High CPU Usage

**Symptoms:** cBot consuming excessive CPU

**Solutions:**
1. Increase poll interval (e.g., 10000 ms instead of 5000 ms)
2. Disable logging if not needed
3. Check for infinite loops in logs
4. Restart cBot

### Issue 6: Trades Not Executing

**Symptoms:** Signals received but no trades executed

**Solutions:**
1. Check account has sufficient balance
2. Verify symbol is available in your account
3. Check volume is within limits
4. Verify stop loss/take profit levels are valid
5. Check account trading permissions
6. Review cBot logs for error messages

### Issue 7: HTTPS Certificate Error

**Error:** `The SSL connection could not be established`

**Solutions:**
1. Set `Use HTTPS` to `false` for testing
2. Verify SSL certificate is valid
3. Check certificate domain matches server
4. For self-signed certificates, may need to disable validation

---

## Best Practices

### Security

1. **Use HTTPS in Production**
   - Always use HTTPS for production trading
   - Verify SSL certificate is valid
   - Use strong passwords for webhook server

2. **Secure Server Access**
   - Restrict webhook server access to known IPs
   - Use firewall rules
   - Monitor access logs

3. **Protect Credentials**
   - Don't hardcode sensitive information
   - Use environment variables if needed
   - Keep cBot code secure

### Performance

1. **Optimize Poll Interval**
   - 5 seconds is good for most use cases
   - Don't set too low (increases CPU usage)
   - Don't set too high (may miss signals)

2. **Monitor Resource Usage**
   - Check CPU usage regularly
   - Monitor memory consumption
   - Watch network bandwidth

3. **Error Handling**
   - cBot handles errors gracefully
   - Check logs for warnings
   - Restart if needed

### Trading

1. **Start Small**
   - Begin with small volume (0.01 lots)
   - Test thoroughly before scaling
   - Monitor trades carefully

2. **Risk Management**
   - Always use stop loss
   - Set appropriate take profit
   - Monitor account balance

3. **Testing**
   - Test in backtest mode first
   - Test with small volume in live trading
   - Monitor for at least 24 hours

### Monitoring

1. **Check Logs Regularly**
   - Review cBot logs daily
   - Look for errors or warnings
   - Monitor trade execution

2. **Monitor Server**
   - Ensure webhook bridge server is running
   - Check server logs for errors
   - Monitor server resources

3. **Monitor Trades**
   - Review executed trades
   - Check for unexpected behavior
   - Verify stop loss/take profit levels

---

## Advanced Configuration

### Custom Stop Loss/Take Profit

Modify the `ExecuteTradeAsync` method to use custom logic:

```csharp
// Example: Dynamic stop loss based on volatility
double volatility = CalculateVolatility(symbol);
double dynamicStopLoss = StopLossPips + (int)(volatility * 10);
```

### Multiple Symbols

To trade multiple symbols, modify the signal handling:

```csharp
// In ExecuteTradeAsync, add symbol filtering
if (signal.Symbol != "EURUSD")
    return; // Only trade EURUSD
```

### Custom Trade Logic

Add custom logic before executing trade:

```csharp
// Example: Only trade during specific hours
if (DateTime.Now.Hour < 8 || DateTime.Now.Hour > 17)
    return; // Only trade 8 AM to 5 PM
```

---

## Performance Metrics

### Expected Performance

- **Response Time:** <1 second from signal to trade execution
- **CPU Usage:** <5% under normal conditions
- **Memory Usage:** ~50-100 MB
- **Network Bandwidth:** <1 KB per poll

### Optimization Tips

1. Increase poll interval if CPU usage is high
2. Disable logging if not needed
3. Use smaller volume for faster execution
4. Monitor and adjust parameters based on performance

---

## Support & Resources

### cTrader Documentation
- cAlgo API: https://ctrader.com/algos/reference/
- cBot Development: https://ctrader.com/algos/guides/
- Community: https://ctrader.com/forum/

### Webhook Bridge Documentation
- See `README.md` in webhook bridge package
- See `DOKPLOY_DEPLOYMENT.md` for server setup
- See `COMMANDS_REFERENCE.md` for server commands

### Troubleshooting Resources
- cTrader Support: https://support.ctrader.com/
- cAlgo Community: https://ctrader.com/forum/
- GitHub Issues: Check webhook bridge repository

---

## Checklist

Before going live:
- [ ] cBot compiles without errors
- [ ] Webhook bridge server is running
- [ ] Server connection is working
- [ ] Test signal is received and logged
- [ ] Trade is executed correctly
- [ ] Duplicate detection is working
- [ ] Error handling is working
- [ ] Stop loss and take profit are set
- [ ] Volume is appropriate for account
- [ ] Logging is enabled
- [ ] cBot has been tested for 24+ hours
- [ ] Account has sufficient balance
- [ ] All symbols are available in account

---

## Quick Reference

### cBot Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| Server IP | localhost | - | Webhook server IP/domain |
| Server Port | 25345 | 1-65535 | Webhook server port |
| Use HTTPS | false | true/false | Use HTTPS protocol |
| Volume | 0.1 | 0.01-100 | Trade volume in lots |
| Stop Loss | 50 | 0-1000 | Stop loss in pips |
| Take Profit | 100 | 0-1000 | Take profit in pips |
| Poll Interval | 5000 | 1000-60000 | Polling interval in ms |
| Enable Logging | true | true/false | Enable logging |

### Log Messages

| Message | Meaning |
|---------|---------|
| `Robot initialized successfully` | cBot started |
| `New signal received` | Signal received from server |
| `Trade executed` | Trade placed successfully |
| `Duplicate signal ignored` | Same signal received again |
| `ERROR: Symbol not found` | Symbol not available |
| `WARNING: HTTP request failed` | Server connection error |
| `Robot stopped` | cBot stopped |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-27 | Initial release |

---

**Last Updated:** May 27, 2026
**Status:** Production Ready
