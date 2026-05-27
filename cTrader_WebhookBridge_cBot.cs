using cAlgo.API;
using cAlgo.API.Internals;
using System;
using System.Net;
using System.Text.Json;

namespace cAlgo.Robots
{
    [Robot(TimeZone = TimeZones.UTC, AccessRights = AccessRights.None)]
    public class TradingViewWebhookBridge : Robot
    {
        // =========================================================
        // PARAMETERS
        // =========================================================

        [Parameter("Server URL", DefaultValue = "http://ctrader.emmanuelshekinah.co.za:25345/signal")]
        public string ServerUrl { get; set; }

        [Parameter("Poll Seconds", DefaultValue = 5)]
        public int PollSeconds { get; set; }

        [Parameter("Enable Trading", DefaultValue = false)]
        public bool EnableTrading { get; set; }

        [Parameter("Volume (Lots)", DefaultValue = 0.01, MinValue = 0.01, Step = 0.01)]
        public double VolumeLots { get; set; }

        [Parameter("Stop Loss (Pips)", DefaultValue = 50)]
        public int StopLossPips { get; set; }

        [Parameter("Take Profit (Pips)", DefaultValue = 100)]
        public int TakeProfitPips { get; set; }

        [Parameter("Label", DefaultValue = "TVBridge")]
        public string Label { get; set; }

        // =========================================================
        // PRIVATE VARIABLES
        // =========================================================

        private string _lastSignalId = "";

        // =========================================================
        // START
        // =========================================================

        protected override void OnStart()
        {
            Print("====================================");
            Print("TradingView Webhook Bridge Started");
            Print($"Server URL: {ServerUrl}");
            Print($"Poll Seconds: {PollSeconds}");
            Print($"Trading Enabled: {EnableTrading}");
            Print("====================================");

            Timer.Start(PollSeconds);
        }

        // =========================================================
        // TIMER EVENT
        // =========================================================

        protected override void OnTimer()
        {
            try
            {
                using (var client = new WebClient())
                {
                    // Download JSON from webhook bridge
                    string json = client.DownloadString(ServerUrl);

                    Print("RAW JSON:");
                    Print(json);

                    // Deserialize JSON
                    var response = JsonSerializer.Deserialize<SignalData>(
                        json,
                        new JsonSerializerOptions
                        {
                            PropertyNameCaseInsensitive = true
                        });

                    // Validate response
                    if (response == null)
                    {
                        Print("Response is null");
                        Print($"Raw JSON: {json}");
                        return;
                    }

                    // Create unique signal ID
                    string signalId =
                        $"{response.symbol}_{response.action}_{response.time}";

                    // Prevent duplicate execution
                    if (signalId == _lastSignalId)
                    {
                        Print("Duplicate signal ignored");
                        return;
                    }

                    // Save last signal
                    _lastSignalId = signalId;

                    // Print signal
                    Print("====================================");
                    Print("NEW SIGNAL RECEIVED");
                    Print($"Symbol : {response.symbol}");
                    Print($"Action : {response.action}");
                    Print($"Price  : {response.price}");
                    Print($"Time   : {response.time}");
                    Print("====================================");

                    // Trading disabled
                    if (!EnableTrading)
                    {
                        Print("TEST MODE ENABLED");
                        Print("Trade execution skipped");
                        return;
                    }

                    // Execute trade
                    ExecuteSignal(response);
                }
            }
            catch (WebException ex)
            {
                Print("WEB ERROR:");
                Print(ex.Message);
            }
            catch (JsonException ex)
            {
                Print("JSON ERROR:");
                Print(ex.Message);
            }
            catch (Exception ex)
            {
                Print("GENERAL ERROR:");
                Print(ex.Message);
            }
        }

        // =========================================================
        // EXECUTE SIGNAL
        // =========================================================

        private void ExecuteSignal(SignalData signal)
        {
            try
            {
                // Validate symbol
                var symbol = Symbols.GetSymbol(signal.symbol);

                if (symbol == null)
                {
                    Print($"Symbol not found: {signal.symbol}");
                    return;
                }

                // Determine trade direction
                TradeType tradeType;

                if (signal.action.ToUpper() == "BUY")
                {
                    tradeType = TradeType.Buy;
                }
                else if (signal.action.ToUpper() == "SELL")
                {
                    tradeType = TradeType.Sell;
                }
                else
                {
                    Print($"Invalid action: {signal.action}");
                    return;
                }

                // Convert lots to units
                double volumeInUnits =
                    symbol.QuantityToVolumeInUnits(VolumeLots);

                Print("EXECUTING TRADE...");
                Print($"Type   : {tradeType}");
                Print($"Volume : {VolumeLots} lots");
                Print($"Units  : {volumeInUnits}");

                // Execute market order
                var result = ExecuteMarketOrder(
                    tradeType,
                    signal.symbol,
                    volumeInUnits,
                    Label,
                    StopLossPips,
                    TakeProfitPips
                );

                // Result
                if (result.IsSuccessful)
                {
                    Print("====================================");
                    Print("TRADE EXECUTED SUCCESSFULLY");
                    Print($"Position ID: {result.Position.Id}");
                    Print($"Entry Price: {result.Position.EntryPrice}");
                    Print("====================================");
                }
                else
                {
                    Print("====================================");
                    Print("TRADE FAILED");
                    Print($"Error: {result.Error}");
                    Print("====================================");
                }
            }
            catch (Exception ex)
            {
                Print("EXECUTION ERROR:");
                Print(ex.Message);
            }
        }

        // =========================================================
        // STOP
        // =========================================================

        protected override void OnStop()
        {
            Print("====================================");
            Print("TradingView Webhook Bridge Stopped");
            Print("====================================");
        }
    }

    // =============================================================
    // SIGNAL DATA MODEL
    // =============================================================

    public class SignalData
    {
        public string symbol { get; set; }

        public string action { get; set; }

        public string price { get; set; }

        public string time { get; set; }

        public string received_at { get; set; }
    }
}