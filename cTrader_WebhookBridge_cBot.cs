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
        /// Stop loss in net USD dollars
        /// Position closes when loss reaches this amount
        /// </summary>
        [Parameter("Stop Loss (USD)", DefaultValue = 100, MinValue = 0, Step = 10, Group = "Trading")]
        public double StopLossUSD { get; set; }

        /// <summary>
        /// Take profit in net USD dollars
        /// Position closes when profit reaches this amount
        /// </summary>
        [Parameter("Take Profit (USD)", DefaultValue = 200, MinValue = 0, Step = 10, Group = "Trading")]
        public double TakeProfitUSD { get; set; }

        /// <summary>
        /// Unique broker/client identifier
        /// Used to track which brokers have fetched each signal
        /// </summary>
        [Parameter("Broker ID", DefaultValue = "ctrader_1", Group = "Server")]
        public string BrokerId { get; set; }

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
                // Build webhook server URL
                string protocol = UseHttps ? "https" : "http";
                string url = "http://ctrader.emmanuelshekinah.co.za:25345/signal";//$"{protocol}://{ServerIP}:{ServerPort}/signal";

                // Fetch signal from webhook server
                WebhookSignal signal = await FetchSignalAsync(url);

                // Check if signal is valid
                if (signal != null)
                {
                    // Check signal status first
                    if (signal.Status == "success")
                    {
                        // Prevent concurrent polling with lock
                        lock (_lockObject)
                        {
                            // Only check for duplicates if status is success
                            if (!IsDuplicateSignal(signal))
                            {
                                Log($"✓ NEW SIGNAL: {signal.Symbol} {signal.Action} @ {signal.Entry}");
                                Log($"  Entry: {signal.Entry} | SL: {signal.StopLoss} | TP: {string.Join(",", signal.TakeProfitLevels ?? new List<double>())}");

                                // Update last signal tracking
                                _lastSignal = signal;
                                _lastSignalTime = DateTime.UtcNow;

                                // Execute trade on main thread
                                BeginInvokeOnMainThread(async () =>
                                {
                                    try
                                    {
                                        await ExecuteTradeAsync(signal);
                                    }
                                    catch (Exception ex)
                                    {
                                        Log($"ERROR executing trade: {ex.Message}");
                                    }
                                });
                            }
                        }
                    }
                    else if (signal.Status == "no_signal")
                    {
                        // Quietly skip - no signal yet (don't spam logs)
                    }
                    else if (signal.Status == "error")
                    {
                        Log($"⚠ Server error: {signal.Status}");
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
                // Append broker ID to URL
                string urlWithId = $"{url}?id={BrokerId}";
                
                // Send GET request to webhook server
                HttpResponseMessage response = await _httpClient.GetAsync(urlWithId);

                // Check if request was successful
                if (!response.IsSuccessStatusCode)
                {
                    Log($"WARNING: Server returned status {response.StatusCode}");
                    return null;
                }

                // Read response content
                string content = await response.Content.ReadAsStringAsync();
                Log($"✓ HTTP {response.StatusCode} | Response: {content}");

                // Deserialize JSON to WebhookSignal object
                var options = new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                WebhookSignal signal = System.Text.Json.JsonSerializer.Deserialize<WebhookSignal>(content, options);

                if (signal != null && signal.Status == "success")
                {
                    Log($"✓ SUCCESS RESPONSE PARSED: {signal.Symbol} {signal.Action}");
                }
                else if (signal != null && signal.Status == "already_fetched")
                {
                    Log($"ℹ Already fetched this signal (other brokers: {signal.FetchedBy})");
                }

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
                //return true;
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
                Log($"Signal Entry: {signal.Entry}");

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
                        // BUY: Enter when price <= entry price
                        if (currentPrice <= signal.Entry)
                        {
                            entryConditionMet = true;
                            Log($"✓ Entry condition met for BUY at {currentPrice}");
                        }
                    }
                    else // SELL
                    {
                        // SELL: Enter when price >= entry price
                        if (currentPrice >= signal.Entry)
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
                    double currentPrice = tradeType == TradeType.Buy ? symbol.Ask : symbol.Bid;

                    Log($"✓ Opening position without SL/TP");
                    Log($"  Entry Price: {currentPrice}");
                    Log($"  SL Target: ${StopLossUSD} loss");
                    Log($"  TP Target: ${TakeProfitUSD} profit");

                    // Execute market order WITHOUT SL/TP (we'll monitor manually)
                    TradeResult result = ExecuteMarketOrder(tradeType, symbol, Volume, "WebhookBridge");

                    // Log trade result
                    if (result.IsSuccessful)
                    {
                        Log($"✓ POSITION OPENED");
                        Log($"  Type: {tradeType} | Volume: {Volume} | Symbol: {symbol.Name}");
                        Log($"  Entry Price: {currentPrice}");
                        Log($"  Position ID: {result.Position.Id}");
                    }
                    else
                    {
                        Log($"✗ POSITION OPEN FAILED: {result.Error}");
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
        /// Called on every tick - monitors positions for SL/TP in net USD
        /// </summary>
        protected override void OnTick()
        {
            try
            {
                // Get all open positions from the webhook bridge
                var positions = Positions.FindAll("WebhookBridge");

                if (positions == null || positions.Length == 0)
                    return;

                foreach (var position in positions)
                {
                    // Calculate net P&L in USD
                    double netPnL = position.NetProfit;

                    // Check if SL is triggered (loss >= target loss)
                    if (StopLossUSD > 0 && netPnL <= -StopLossUSD)
                    {
                        Log($"🛑 SL TRIGGERED on Position {position.Id}: Loss ${Math.Abs(netPnL):F2}");
                        ClosePosition(position);
                    }
                    // Check if TP is triggered (profit >= target profit)
                    else if (TakeProfitUSD > 0 && netPnL >= TakeProfitUSD)
                    {
                        Log($"✓ TP TRIGGERED on Position {position.Id}: Profit ${netPnL:F2}");
                        ClosePosition(position);
                    }
                }
            }
            catch (Exception ex)
            {
                Log($"ERROR in OnTick: {ex.Message}");
            }
        }

        /// <summary>
        /// Closes a position
        /// </summary>
        private void ClosePosition(Position position)
        {
            try
            {
                ClosePositionAsync(position);
            }
            catch (Exception ex)
            {
                Log($"ERROR closing position {position.Id}: {ex.Message}");
            }
        }

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
        /// List of brokers that have already fetched this signal
        /// </summary>
        [JsonPropertyName("fetched_by")]
        public List<string> FetchedBy { get; set; }

        /// <summary>
        /// Override ToString for logging
        /// </summary>
        public override string ToString()
        {
            return $"Signal(Symbol={Symbol}, Action={Action}, Entry={Entry}, SL={StopLoss}, TP={string.Join(",", TakeProfitLevels ?? new List<double>())})";
        }
    }
}
