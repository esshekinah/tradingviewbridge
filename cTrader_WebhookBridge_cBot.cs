using cAlgo.API;
using cAlgo.API.Internals;
using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Threading.Tasks;
using System.Text.Json.Serialization;

namespace cAlgo.Robots
{
    /// <summary>
    /// TradingView Webhook Bridge cBot
    /// 
    /// This cBot connects to a Python webhook bridge server and executes trades
    /// based on signals received from TradingView alerts.
    /// 
    /// Features:
    /// - Polls webhook server every 5 seconds
    /// - Deserializes JSON signals
    /// - Prevents duplicate signals
    /// - Async HTTP requests
    /// - Comprehensive error handling
    /// - Production-ready logging
    /// 
    /// Configuration:
    /// - Set SERVER_IP to your webhook bridge server IP
    /// - Set VOLUME to desired trade volume
    /// - Adjust POLL_INTERVAL_MS if needed
    /// </summary>
    [Robot(TimeZone = TimeZones.UTC, AccessRights = AccessRights.None)]
    public class TradingViewWebhookBridge : Robot
    {
        // ============================================================================
        // CONFIGURATION PARAMETERS
        // ============================================================================

        /// <summary>
        /// Webhook bridge server IP address or hostname
        /// Example: "192.168.1.100" or "ctrader.emmanuelshekinah.co.za"
        /// </summary>
        [Parameter("Server IP/Domain", DefaultValue = "http://ctrader.emmanuelshekinah.co.za", Group = "Server")]
        public string ServerIP { get; set; }

        /// <summary>
        /// Webhook bridge server port
        /// Default: 25345
        /// </summary>
        [Parameter("Server Port", DefaultValue = 25345, Group = "Server")]
        public int ServerPort { get; set; }

        /// <summary>
        /// Use HTTPS for secure connection
        /// Set to true for production (requires valid SSL certificate)
        /// </summary>
        [Parameter("Use HTTPS", DefaultValue = false, Group = "Server")]
        public bool UseHttps { get; set; }

        /// <summary>
        /// Polling interval in milliseconds
        /// Default: 5000 (5 seconds)
        /// </summary>
        [Parameter("Poll Interval (ms)", DefaultValue = 5000, Group = "Polling")]
        public int PollIntervalMs { get; set; }

        /// <summary>
        /// Trade volume in lots
        /// </summary>
        [Parameter("Volume (Lots)", DefaultValue = 0.1, MinValue = 0.01, Step = 0.01, Group = "Trading")]
        public double Volume { get; set; }

        /// <summary>
        /// Stop loss in pips
        /// Set to 0 to disable
        /// </summary>
        [Parameter("Stop Loss (pips)", DefaultValue = 50, MinValue = 0, Group = "Trading")]
        public int StopLossPips { get; set; }

        /// <summary>
        /// Take profit in pips
        /// Set to 0 to disable
        /// </summary>
        [Parameter("Take Profit (pips)", DefaultValue = 100, MinValue = 0, Group = "Trading")]
        public int TakeProfitPips { get; set; }

        /// <summary>
        /// Entry timeout in seconds
        /// How long to wait for entry price condition before timing out
        /// </summary>
        [Parameter("Entry Timeout (seconds)", DefaultValue = 120, MinValue = 10, Step = 10, Group = "Trading")]
        public int EntryTimeoutSeconds { get; set; }

        /// <summary>
        /// Enable logging to cTrader logs
        /// </summary>
        [Parameter("Enable Logging", DefaultValue = true, Group = "Logging")]
        public bool EnableLogging { get; set; }

        // ============================================================================
        // PRIVATE FIELDS
        // ============================================================================

        /// <summary>
        /// HTTP client for async requests
        /// </summary>
        private HttpClient _httpClient;

        /// <summary>
        /// Last received signal to prevent duplicates
        /// </summary>
        private WebhookSignal _lastSignal;

        /// <summary>
        /// Timestamp of last signal to track duplicates
        /// </summary>
        private DateTime _lastSignalTime;

        /// <summary>
        /// Timer for polling the webhook server
        /// </summary>
        private System.Timers.Timer _pollTimer;

        /// <summary>
        /// Lock object for thread-safe operations
        /// </summary>
        private readonly object _lockObject = new object();

        /// <summary>
        /// Flag to track if robot is running
        /// </summary>
        private bool _isRunning = false;

        // ============================================================================
        // INITIALIZATION
        // ============================================================================

        /// <summary>
        /// Called when the robot starts
        /// Initializes HTTP client and polling timer
        /// </summary>
        protected override void OnStart()
        {
            try
            {
                Log("=== TradingView Webhook Bridge cBot Started ===");
                Log($"Server: {ServerIP}:{ServerPort}");
                Log($"Protocol: {(UseHttps ? "HTTPS" : "HTTP")}");
                Log($"Poll Interval: {PollIntervalMs}ms");
                Log($"Volume: {Volume} lots");

                // Initialize HTTP client with timeout
                _httpClient = new HttpClient();
                _httpClient.Timeout = TimeSpan.FromSeconds(10);

                // Initialize signal tracking
                _lastSignal = null;
                _lastSignalTime = DateTime.MinValue;

                // Setup polling timer
                _pollTimer = new System.Timers.Timer(PollIntervalMs);
                _pollTimer.Elapsed += async (sender, e) => await PollWebhookServer();
                _pollTimer.AutoReset = true;
                _pollTimer.Start();

                _isRunning = true;
                Log("Robot initialized successfully");
            }
            catch (Exception ex)
            {
                Log($"ERROR in OnStart: {ex.Message}");
                Stop();
            }
        }

        // ============================================================================
        // MAIN POLLING LOGIC
        // ============================================================================

        /// <summary>
        /// Polls the webhook server for new signals
        /// Called every PollIntervalMs milliseconds
        /// </summary>
        private async Task PollWebhookServer()
        {
            try
            {
                // Prevent concurrent polling
                lock (_lockObject)
                {
                    // Build webhook server URL
                    string protocol = UseHttps ? "https" : "http";
                    string url = "http://ctrader.emmanuelshekinah.co.za:25345/signal";//$"{protocol}://{ServerIP}:{ServerPort}/signal";

                    // Fetch signal from webhook server
                    var task = FetchSignalAsync(url);
                    task.Wait(TimeSpan.FromSeconds(10));
                    WebhookSignal signal = task.Result;

                    // Check if signal is valid
                    if (signal != null)
                    {
                        // Check signal status first
                        if (signal.Status == "success")
                        {
                            // Only check for duplicates if status is success
                            if (!IsDuplicateSignal(signal))
                            {
                                Log($"New signal received: {signal.Symbol} {signal.Action} @ {signal.Entry}");

                                // Update last signal tracking
                                _lastSignal = signal;
                                _lastSignalTime = DateTime.UtcNow;

                                // Execute trade based on signal
                                var executeTask = ExecuteTradeAsync(signal);
                                executeTask.Wait();
                            }
                        }
                        else if (signal.Status == "no_signal")
                        {
                            Log("No signal available yet");
                        }
                        else if (signal.Status == "error")
                        {
                            Log($"Server error: {signal.Status}");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Log($"ERROR in PollWebhookServer: {ex.Message}");
            }
        }

        // ============================================================================
        // HTTP REQUEST HANDLING
        // ============================================================================

        /// <summary>
        /// Fetches signal from webhook server asynchronously
        /// </summary>
        /// <param name="url">Webhook server URL</param>
        /// <returns>Deserialized WebhookSignal or null if error</returns>
        private async Task<WebhookSignal> FetchSignalAsync(string url)
        {
            try
            {
                // Send GET request to webhook server
                HttpResponseMessage response = await _httpClient.GetAsync(url);

                // Check if request was successful
                if (!response.IsSuccessStatusCode)
                {
                    Log($"WARNING: Server returned status {response.StatusCode}");
                    return null;
                }

                // Read response content
                string content = await response.Content.ReadAsStringAsync();
                Log("Response: "+ content);

                // Deserialize JSON to WebhookSignal object
                var options = new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                WebhookSignal signal = System.Text.Json.JsonSerializer.Deserialize<WebhookSignal>(content, options);

                return signal;
            }
            catch (HttpRequestException ex)
            {
                Log($"WARNING: HTTP request failed - {ex.Message}");
                return null;
            }
            catch (System.Text.Json.JsonException ex)
            {
                Log($"WARNING: JSON deserialization failed - {ex.Message}");
                return null;
            }
            catch (TaskCanceledException ex)
            {
                Log($"WARNING: Request timeout - {ex.Message}");
                return null;
            }
            catch (Exception ex)
            {
                Log($"ERROR in FetchSignalAsync: {ex.Message}");
                return null;
            }
        }

        // ============================================================================
        // DUPLICATE SIGNAL DETECTION
        // ============================================================================

        /// <summary>
        /// Checks if signal is a duplicate of the last received signal
        /// Prevents executing the same signal multiple times
        /// </summary>
        /// <param name="signal">Signal to check</param>
        /// <returns>True if signal is duplicate, false otherwise</returns>
        private bool IsDuplicateSignal(WebhookSignal signal)
        {
            // No previous signal, so this is not a duplicate
            if (_lastSignal == null)
                return false;

            // Check if signal matches last signal (comparing symbol, action, and entry price)
            bool isSameSymbol = signal.Symbol == _lastSignal.Symbol;
            bool isSameAction = signal.Action == _lastSignal.Action;
            bool isSameEntry = Math.Abs(signal.Entry - _lastSignal.Entry) < 0.01; // Allow small difference

            // If all properties match, it's a duplicate
            if (isSameSymbol && isSameAction && isSameEntry)
            {
                // Log duplicate detection
                Log($"Duplicate signal ignored: {signal.Symbol} {signal.Action} @ {signal.Entry}");
                return true;
            }

            return false;
        }

        // ============================================================================
        // TRADE EXECUTION
        // ============================================================================

        /// <summary>
        /// Executes trade based on received signal
        /// Watches price and enters when price is at entry or between SL and entry
        /// Uses signal's SL and TP3 (third TP level)
        /// </summary>
        /// <param name="signal">WebhookSignal containing trade details</param>
        private async Task ExecuteTradeAsync(WebhookSignal signal)
        {
            try
            {
                Log(signal.Action);
                Log(signal.Symbol);

                // Validate signal
                if (string.IsNullOrEmpty(signal.Action))
                {
                    Log("ERROR: Invalid signal - missing symbol or action: ");
                    //Log(signal);
                    return;
                }

                // Get symbol from cTrader
                Symbol symbol = Symbols.GetSymbol(signal.Symbol);
                if (symbol == null)
                {
                    Log($"ERROR: Symbol not found - {signal.Symbol}");
                    return;
                }

                // Determine trade direction
                TradeType tradeType = signal.Action.ToUpper() == "BUY" ? TradeType.Buy : TradeType.Sell;

                Log($"Waiting for entry price condition...");
                Log($"Signal Entry: {signal.Entry}, SL: {signal.StopLoss}");

                // Watch price and wait for entry condition
                bool entryConditionMet = false;
                int checkCount = 0;
                int maxChecks = EntryTimeoutSeconds; // 1 check per second

                while (checkCount < maxChecks && !entryConditionMet)
                {
                    double currentPrice = tradeType == TradeType.Buy ? symbol.Ask : symbol.Bid;

                    // Check entry conditions based on trade direction
                    if (tradeType == TradeType.Buy)
                    {
                        // BUY: Enter if current price is at entry or between SL and entry
                        // (since entry is typically above SL for BUY)
                        if (currentPrice >= signal.StopLoss && currentPrice <= signal.Entry)
                        {
                            entryConditionMet = true;
                            Log($"✓ Entry condition met for BUY at {currentPrice}");
                        }
                    }
                    else // SELL
                    {
                        // SELL: Enter if current price is at entry or between entry and SL
                        // (since SL is typically above entry for SELL)
                        if (currentPrice >= signal.Entry && currentPrice <= signal.StopLoss)
                        {
                            entryConditionMet = true;
                            Log($"✓ Entry condition met for SELL at {currentPrice}");
                        }
                    }

                    if (!entryConditionMet)
                    {
                        checkCount++;
                        await Task.Delay(1000); // Wait 1 second before next check
                    }
                }

                // If entry condition met, execute trade
                if (entryConditionMet)
                {
                    double? stopLoss = null;
                    double? takeProfit = null;

                    // Use SL from signal if available, otherwise use fallback from parameters
                    if (signal.StopLoss > 0)
                    {
                        stopLoss = signal.StopLoss;
                        Log($"Using SL from signal: {stopLoss}");
                    }
                    else if (StopLossPips > 0)
                    {
                        stopLoss = tradeType == TradeType.Buy
                            ? symbol.Bid - (StopLossPips * symbol.PipSize)
                            : symbol.Ask + (StopLossPips * symbol.PipSize);
                        Log($"Using fallback SL from parameters: {stopLoss} ({StopLossPips} pips)");
                    }

                    // Use TP from signal if available, otherwise use fallback from parameters
                    if (signal.TakeProfitLevels != null && signal.TakeProfitLevels.Count >= 3)
                    {
                        // Use TP3 (third TP level)
                        takeProfit = signal.TakeProfitLevels[2];
                        Log($"Using TP3 from signal: {takeProfit}");
                    }
                    else if (signal.TakeProfitLevels != null && signal.TakeProfitLevels.Count > 0)
                    {
                        // If TP3 not available, use last available TP from signal
                        takeProfit = signal.TakeProfitLevels[signal.TakeProfitLevels.Count - 1];
                        Log($"Using last TP from signal: {takeProfit}");
                    }
                    else if (TakeProfitPips > 0)
                    {
                        // Fallback to TP from parameters
                        takeProfit = tradeType == TradeType.Buy
                            ? symbol.Bid + (TakeProfitPips * symbol.PipSize)
                            : symbol.Ask - (TakeProfitPips * symbol.PipSize);
                        Log($"Using fallback TP from parameters: {takeProfit} ({TakeProfitPips} pips)");
                    }

                    // Execute market order
                    TradeResult result = ExecuteMarketOrder(tradeType, symbol, Volume, "WebhookBridge", stopLoss, takeProfit);

                    // Log trade result
                    if (result.IsSuccessful)
                    {
                        Log($"✓ Trade executed: {tradeType} {Volume} {symbol.Name} @ {(tradeType == TradeType.Buy ? symbol.Ask : symbol.Bid)}");
                        Log($"  Signal Entry: {signal.Entry}");
                        Log($"  Stop Loss: {stopLoss}");
                        Log($"  Take Profit: {takeProfit}");
                        Log($"  Position ID: {result.Position.Id}");
                    }
                    else
                    {
                        Log($"✗ Trade failed: {result.Error}");
                    }
                }
                else
                {
                    Log($"⚠ Entry condition not met within {EntryTimeoutSeconds} seconds timeout period");
                }
            }
            catch (Exception ex)
            {
                Log($"ERROR in ExecuteTradeAsync: {ex.Message}");
            }
        }

        // ============================================================================
        // LOGGING
        // ============================================================================

        /// <summary>
        /// Logs message to cTrader logs with timestamp
        /// </summary>
        /// <param name="message">Message to log</param>
        private void Log(string message)
        {
            if (!EnableLogging)
                return;

            string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
            string logMessage = $"[{timestamp}] {message}";

            // Log to cTrader
            Print(logMessage);
        }

        // ============================================================================
        // CLEANUP
        // ============================================================================

        /// <summary>
        /// Called when the robot stops
        /// Cleans up resources
        /// </summary>
        protected override void OnStop()
        {
            try
            {
                _isRunning = false;

                // Stop polling timer
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
    }

    // ============================================================================
    // DATA MODELS
    // ============================================================================

    /// <summary>
    /// Represents a signal received from the webhook bridge server
    /// Matches the JSON structure from the Python webhook bridge
    /// </summary>
    public class WebhookSignal
    {
        /// <summary>
        /// Trading symbol (e.g., "XAUUSD", "EURUSD")
        /// </summary>
        [JsonPropertyName("symbol")]
        public string Symbol { get; set; }

        /// <summary>
        /// Trade action: "BUY" or "SELL"
        /// </summary>
        [JsonPropertyName("action")]
        public string Action { get; set; }

        /// <summary>
        /// Signal status: "success", "no_signal", "error"
        /// </summary>
        [JsonPropertyName("status")]
        public string Status { get; set; }

        /// <summary>
        /// Entry price from signal
        /// </summary>
        [JsonPropertyName("entry")]
        public double Entry { get; set; }

        /// <summary>
        /// Stop loss price from signal
        /// </summary>
        [JsonPropertyName("sl")]
        public double StopLoss { get; set; }

        /// <summary>
        /// Take profit levels from signal
        /// </summary>
        [JsonPropertyName("tp_levels")]
        public List<double> TakeProfitLevels { get; set; }

        /// <summary>
        /// Entry price as string (for compatibility)
        /// </summary>
        [JsonPropertyName("price")]
        public string Price { get; set; }

        /// <summary>
        /// Signal timestamp from TradingView
        /// </summary>
        [JsonPropertyName("time")]
        public string Time { get; set; }

        /// <summary>
        /// Server reception timestamp
        /// </summary>
        [JsonPropertyName("received_at")]
        public string ReceivedAt { get; set; }

        /// <summary>
        /// Override ToString for logging
        /// </summary>
        public override string ToString()
        {
            return $"Signal(Symbol={Symbol}, Action={Action}, Entry={Entry}, SL={StopLoss}, TP={string.Join(",", TakeProfitLevels ?? new List<double>())})";
        }
    }
}
