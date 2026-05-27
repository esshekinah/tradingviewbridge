# cBot Code Documentation - TradingView Webhook Bridge

Detailed documentation of the cBot code structure and functionality.

---

## Table of Contents

1. [Overview](#overview)
2. [Class Structure](#class-structure)
3. [Configuration Parameters](#configuration-parameters)
4. [Core Methods](#core-methods)
5. [Data Models](#data-models)
6. [Error Handling](#error-handling)
7. [Thread Safety](#thread-safety)
8. [Performance Considerations](#performance-considerations)

---

## Overview

### Purpose
The `TradingViewWebhookBridge` cBot connects to a Python webhook bridge server and executes trades based on signals received from TradingView alerts.

### Key Features
- Polls webhook server every 5 seconds (configurable)
- Deserializes JSON signals
- Prevents duplicate signals
- Async HTTP requests
- Comprehensive error handling
- Thread-safe operations
- Production-ready logging

### Architecture
```
cBot Start
    ↓
Initialize HTTP Client & Timer
    ↓
Poll Webhook Server (every 5 seconds)
    ↓
Fetch Signal (async)
    ↓
Check for Duplicates
    ↓
Execute Trade
    ↓
Log Result
```

---

## Class Structure

### TradingViewWebhookBridge Class

**Inheritance:** `Robot` (from cAlgo.API)

**Namespace:** `cAlgo.Robots`

**Access Level:** `public`

**Attributes:**
```csharp
[Robot(TimeZone = TimeZoneInfo.Utc, AccessRights = AccessRights.None)]
```

### Class Sections

#### 1. Configuration Parameters
Parameters exposed in cTrader UI for user configuration.

#### 2. Private Fields
Internal state variables for the cBot.

#### 3. Initialization (OnStart)
Called when cBot starts - initializes resources.

#### 4. Main Polling Logic (PollWebhookServer)
Core polling loop that fetches signals.

#### 5. HTTP Request Handling (FetchSignalAsync)
Async HTTP requests to webhook server.

#### 6. Duplicate Detection (IsDuplicateSignal)
Prevents executing same signal twice.

#### 7. Trade Execution (ExecuteTradeAsync)
Executes trades based on signals.

#### 8. Logging (Log)
Logs messages to cTrader.

#### 9. Cleanup (OnStop)
Called when cBot stops - cleans up resources.

---

## Configuration Parameters

### Server Configuration

#### ServerIP
```csharp
[Parameter("Server IP/Domain", DefaultValue = "localhost", Group = "Server")]
public string ServerIP { get; set; }
```
- **Type:** `string`
- **Default:** `"localhost"`
- **Examples:** `"192.168.1.100"`, `"ctrader.emmanuelshekinah.co.za"`
- **Purpose:** Webhook bridge server address

#### ServerPort
```csharp
[Parameter("Server Port", DefaultValue = 25345, Group = "Server")]
public int ServerPort { get; set; }
```
- **Type:** `int`
- **Default:** `25345`
- **Range:** `1-65535`
- **Purpose:** Webhook bridge server port

#### UseHttps
```csharp
[Parameter("Use HTTPS", DefaultValue = false, Group = "Server")]
public bool UseHttps { get; set; }
```
- **Type:** `bool`
- **Default:** `false`
- **Purpose:** Use HTTPS for secure connection

### Polling Configuration

#### PollIntervalMs
```csharp
[Parameter("Poll Interval (ms)", DefaultValue = 5000, Group = "Polling")]
public int PollIntervalMs { get; set; }
```
- **Type:** `int`
- **Default:** `5000` (5 seconds)
- **Range:** `1000-60000`
- **Purpose:** Polling interval in milliseconds

### Trading Configuration

#### Volume
```csharp
[Parameter("Volume (Lots)", DefaultValue = 0.1, MinValue = 0.01, Step = 0.01, Group = "Trading")]
public double Volume { get; set; }
```
- **Type:** `double`
- **Default:** `0.1`
- **Range:** `0.01-100`
- **Purpose:** Trade volume in lots

#### StopLossPips
```csharp
[Parameter("Stop Loss (pips)", DefaultValue = 50, MinValue = 0, Group = "Trading")]
public int StopLossPips { get; set; }
```
- **Type:** `int`
- **Default:** `50`
- **Range:** `0-1000`
- **Purpose:** Stop loss in pips (0 = disabled)

#### TakeProfitPips
```csharp
[Parameter("Take Profit (pips)", DefaultValue = 100, MinValue = 0, Group = "Trading")]
public int TakeProfitPips { get; set; }
```
- **Type:** `int`
- **Default:** `100`
- **Range:** `0-1000`
- **Purpose:** Take profit in pips (0 = disabled)

### Logging Configuration

#### EnableLogging
```csharp
[Parameter("Enable Logging", DefaultValue = true, Group = "Logging")]
public bool EnableLogging { get; set; }
```
- **Type:** `bool`
- **Default:** `true`
- **Purpose:** Enable/disable logging

---

## Core Methods

### OnStart()

**Purpose:** Initialize cBot when it starts

**Called:** Once when cBot starts

**Responsibilities:**
1. Log startup message
2. Initialize HTTP client
3. Initialize signal tracking
4. Setup polling timer
5. Start polling

**Code Flow:**
```csharp
protected override void OnStart()
{
    // 1. Log startup
    Log("=== TradingView Webhook Bridge cBot Started ===");
    
    // 2. Initialize HTTP client
    _httpClient = new HttpClient();
    _httpClient.Timeout = TimeSpan.FromSeconds(10);
    
    // 3. Initialize signal tracking
    _lastSignal = null;
    _lastSignalTime = DateTime.MinValue;
    
    // 4. Setup polling timer
    _pollTimer = new System.Timers.Timer(PollIntervalMs);
    _pollTimer.Elapsed += async (sender, e) => await PollWebhookServer();
    _pollTimer.AutoReset = true;
    _pollTimer.Start();
    
    // 5. Mark as running
    _isRunning = true;
}
```

**Error Handling:** Try-catch block logs errors and stops cBot

---

### PollWebhookServer()

**Purpose:** Poll webhook server for new signals

**Called:** Every `PollIntervalMs` milliseconds

**Responsibilities:**
1. Prevent concurrent polling
2. Build webhook URL
3. Fetch signal
4. Check for duplicates
5. Execute trade if new signal

**Code Flow:**
```csharp
private async Task PollWebhookServer()
{
    // 1. Prevent concurrent polling
    if (!Monitor.TryEnter(_lockObject))
        return;
    
    try
    {
        // 2. Build URL
        string url = $"{protocol}://{ServerIP}:{ServerPort}/signal";
        
        // 3. Fetch signal
        WebhookSignal signal = await FetchSignalAsync(url);
        
        // 4. Check for duplicates
        if (signal != null && !IsDuplicateSignal(signal))
        {
            // 5. Execute trade
            _lastSignal = signal;
            _lastSignalTime = DateTime.UtcNow;
            await ExecuteTradeAsync(signal);
        }
    }
    finally
    {
        Monitor.Exit(_lockObject);
    }
}
```

**Thread Safety:** Uses `Monitor.TryEnter()` to prevent concurrent execution

---

### FetchSignalAsync(string url)

**Purpose:** Fetch signal from webhook server asynchronously

**Parameters:**
- `url` (string): Webhook server URL

**Returns:** `Task<WebhookSignal>` - Deserialized signal or null

**Responsibilities:**
1. Send GET request
2. Check response status
3. Read response content
4. Deserialize JSON
5. Handle errors

**Code Flow:**
```csharp
private async Task<WebhookSignal> FetchSignalAsync(string url)
{
    try
    {
        // 1. Send GET request
        HttpResponseMessage response = await _httpClient.GetAsync(url);
        
        // 2. Check status
        if (!response.IsSuccessStatusCode)
            return null;
        
        // 3. Read content
        string content = await response.Content.ReadAsStringAsync();
        
        // 4. Deserialize JSON
        WebhookSignal signal = JsonConvert.DeserializeObject<WebhookSignal>(content);
        
        return signal;
    }
    catch (HttpRequestException ex)
    {
        Log($"WARNING: HTTP request failed - {ex.Message}");
        return null;
    }
    catch (JsonException ex)
    {
        Log($"WARNING: JSON deserialization failed - {ex.Message}");
        return null;
    }
    catch (TaskCanceledException ex)
    {
        Log($"WARNING: Request timeout - {ex.Message}");
        return null;
    }
}
```

**Error Handling:** Catches and logs specific exceptions

---

### IsDuplicateSignal(WebhookSignal signal)

**Purpose:** Check if signal is duplicate of last signal

**Parameters:**
- `signal` (WebhookSignal): Signal to check

**Returns:** `bool` - True if duplicate, false otherwise

**Logic:**
1. If no previous signal, not a duplicate
2. Compare symbol, action, and price
3. If all match, it's a duplicate

**Code Flow:**
```csharp
private bool IsDuplicateSignal(WebhookSignal signal)
{
    // 1. No previous signal
    if (_lastSignal == null)
        return false;
    
    // 2. Compare properties
    bool isSameSymbol = signal.Symbol == _lastSignal.Symbol;
    bool isSameAction = signal.Action == _lastSignal.Action;
    bool isSamePrice = signal.Price == _lastSignal.Price;
    
    // 3. Check if all match
    if (isSameSymbol && isSameAction && isSamePrice)
    {
        Log($"Duplicate signal ignored: {signal.Symbol} {signal.Action}");
        return true;
    }
    
    return false;
}
```

---

### ExecuteTradeAsync(WebhookSignal signal)

**Purpose:** Execute trade based on signal

**Parameters:**
- `signal` (WebhookSignal): Signal containing trade details

**Responsibilities:**
1. Validate signal
2. Get symbol from cTrader
3. Determine trade direction
4. Calculate stop loss/take profit
5. Execute trade
6. Log result

**Code Flow:**
```csharp
private async Task ExecuteTradeAsync(WebhookSignal signal)
{
    try
    {
        // 1. Validate signal
        if (string.IsNullOrEmpty(signal.Symbol))
            return;
        
        // 2. Get symbol
        Symbol symbol = Symbols.GetSymbolOmitError(signal.Symbol);
        if (symbol == null)
        {
            Log($"ERROR: Symbol not found - {signal.Symbol}");
            return;
        }
        
        // 3. Determine direction
        TradeType tradeType = signal.Action.ToUpper() == "BUY" 
            ? TradeType.Buy 
            : TradeType.Sell;
        
        // 4. Calculate levels
        double? stopLoss = null;
        double? takeProfit = null;
        
        if (StopLossPips > 0)
        {
            stopLoss = tradeType == TradeType.Buy
                ? symbol.Bid - (StopLossPips * symbol.PipSize)
                : symbol.Ask + (StopLossPips * symbol.PipSize);
        }
        
        if (TakeProfitPips > 0)
        {
            takeProfit = tradeType == TradeType.Buy
                ? symbol.Bid + (TakeProfitPips * symbol.PipSize)
                : symbol.Ask - (TakeProfitPips * symbol.PipSize);
        }
        
        // 5. Execute trade
        TradeResult result = ExecuteMarketOrder(
            tradeType, symbol, Volume, "WebhookBridge", 
            stopLoss, takeProfit
        );
        
        // 6. Log result
        if (result.IsSuccessful)
        {
            Log($"✓ Trade executed: {tradeType} {Volume} {symbol.Name}");
        }
        else
        {
            Log($"✗ Trade failed: {result.Error}");
        }
    }
    catch (Exception ex)
    {
        Log($"ERROR in ExecuteTradeAsync: {ex.Message}");
    }
}
```

---

### Log(string message)

**Purpose:** Log message to cTrader with timestamp

**Parameters:**
- `message` (string): Message to log

**Format:** `[YYYY-MM-DD HH:MM:SS.fff] message`

**Code:**
```csharp
private void Log(string message)
{
    if (!EnableLogging)
        return;
    
    string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
    string logMessage = $"[{timestamp}] {message}";
    
    Print(logMessage);
}
```

---

### OnStop()

**Purpose:** Clean up resources when cBot stops

**Called:** Once when cBot stops

**Responsibilities:**
1. Mark as not running
2. Stop polling timer
3. Dispose HTTP client
4. Log stop message

**Code Flow:**
```csharp
protected override void OnStop()
{
    try
    {
        _isRunning = false;
        
        // Stop timer
        if (_pollTimer != null)
        {
            _pollTimer.Stop();
            _pollTimer.Dispose();
        }
        
        // Dispose HTTP client
        if (_httpClient != null)
        {
            _httpClient.Dispose();
        }
        
        Log("=== TradingView Webhook Bridge cBot Stopped ===");
    }
    catch (Exception ex)
    {
        Print($"ERROR in OnStop: {ex.Message}");
    }
}
```

---

## Data Models

### WebhookSignal Class

**Purpose:** Represents a signal from webhook server

**Properties:**

#### Symbol
```csharp
[JsonProperty("symbol")]
public string Symbol { get; set; }
```
- Trading symbol (e.g., "XAUUSD", "EURUSD")

#### Action
```csharp
[JsonProperty("action")]
public string Action { get; set; }
```
- Trade action: "BUY" or "SELL"

#### Price
```csharp
[JsonProperty("price")]
public string Price { get; set; }
```
- Entry price as string

#### Time
```csharp
[JsonProperty("time")]
public string Time { get; set; }
```
- Signal timestamp from TradingView

#### ReceivedAt
```csharp
[JsonProperty("received_at")]
public string ReceivedAt { get; set; }
```
- Server reception timestamp

**JSON Example:**
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

## Error Handling

### Exception Types Handled

#### HttpRequestException
```csharp
catch (HttpRequestException ex)
{
    Log($"WARNING: HTTP request failed - {ex.Message}");
    return null;
}
```
- Network connectivity issues
- Server not responding
- Invalid URL

#### JsonException
```csharp
catch (JsonException ex)
{
    Log($"WARNING: JSON deserialization failed - {ex.Message}");
    return null;
}
```
- Invalid JSON format
- Missing required fields
- Type mismatch

#### TaskCanceledException
```csharp
catch (TaskCanceledException ex)
{
    Log($"WARNING: Request timeout - {ex.Message}");
    return null;
}
```
- Request took too long
- Network timeout
- Server not responding

#### General Exception
```csharp
catch (Exception ex)
{
    Log($"ERROR: {ex.Message}");
}
```
- Unexpected errors
- Fallback for unknown exceptions

### Error Recovery

1. **Non-fatal errors:** Log warning and continue
2. **Fatal errors:** Log error and stop cBot
3. **Timeout:** Retry on next poll
4. **Invalid signal:** Skip and wait for next signal

---

## Thread Safety

### Synchronization Mechanisms

#### Monitor.TryEnter()
```csharp
if (!Monitor.TryEnter(_lockObject))
    return;

try
{
    // Critical section
}
finally
{
    Monitor.Exit(_lockObject);
}
```
- Prevents concurrent polling
- Non-blocking (returns immediately if locked)
- Ensures only one poll at a time

#### Lock Object
```csharp
private readonly object _lockObject = new object();
```
- Synchronization primitive
- Prevents race conditions
- Thread-safe signal updates

### Thread-Safe Operations

1. **Signal Updates:** Protected by lock
2. **HTTP Requests:** Async/await pattern
3. **Timer Callbacks:** Non-blocking check
4. **Logging:** Thread-safe Print() method

---

## Performance Considerations

### CPU Usage

**Factors:**
- Poll interval (lower = higher CPU)
- HTTP request time
- JSON deserialization
- Trade execution

**Optimization:**
- Increase poll interval if CPU is high
- Disable logging if not needed
- Use async operations

### Memory Usage

**Typical:** 50-100 MB

**Factors:**
- HTTP client buffer
- Signal objects
- Log messages
- cTrader framework

**Optimization:**
- Dispose resources properly
- Limit log history
- Use object pooling if needed

### Network Bandwidth

**Typical:** <1 KB per poll

**Calculation:**
- Poll interval: 5000 ms
- Request size: ~200 bytes
- Response size: ~300 bytes
- Total: ~500 bytes per poll
- Per hour: ~360 KB

### Response Time

**Expected:** <1 second from signal to trade

**Breakdown:**
- HTTP request: 100-500 ms
- JSON deserialization: 10-50 ms
- Trade execution: 100-500 ms
- Total: 200-1050 ms

---

## Best Practices

### Code Quality
1. Use meaningful variable names
2. Add comments for complex logic
3. Handle all exceptions
4. Use async/await for I/O
5. Follow C# naming conventions

### Performance
1. Use async operations
2. Minimize lock contention
3. Optimize polling interval
4. Cache frequently used data
5. Monitor resource usage

### Reliability
1. Validate all inputs
2. Handle edge cases
3. Log important events
4. Implement retry logic
5. Test thoroughly

### Security
1. Use HTTPS in production
2. Validate server certificates
3. Sanitize log output
4. Protect sensitive data
5. Monitor for attacks

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-27 | Initial release |

---

**Last Updated:** May 27, 2026
**Status:** Production Ready
