// =====================================================================================
// SmcFvgBot.cs
// -------------------------------------------------------------------------------------
// cTrader Automate (cAlgo) C# cBot port of "SMC - FVG Strategy | Emmanuel"
// (source of truth: smc_fvg_strategy.pine, Pine Script v5 strategy).
//
// This bot reimplements the Smart-Money-Concepts market-structure state machine, the
// "last same-direction FVG within a BOS/CHoCH leg" detection, the Internal/Swing/Both
// trade gate, Limit/Market entry with a selectable fib level, a concurrent-order cap,
// indefinite pending orders, and an on-chart stats dashboard. SL/TP support both a
// broker pip mode and a monitored dollar (account-currency net P&L) mode: SL Mode is
// Pips|Dollar and TP Mode is Pips|RRR|Dollar; dollar dimensions are enforced per
// position in OnTick, pip dimensions are attached to the broker order.
//
// -------------------------------------------------------------------------------------
// DOLLAR SL/TP TRADE-OFF (read before using SL/TP Mode = Dollar):
//
//   A DOLLAR dimension attaches NO broker stop/target. It is enforced ONLY by this bot
//   from OnTick while the bot process is running and connected. This is by explicit user
//   design ("if we select dollar we don't have to place sl" -> close on net P&L instead),
//   so NO hidden broker safety-net stop is attached in dollar mode. The consequences the
//   user must be aware of:
//     * If the bot is stopped, crashes, or the platform disconnects while a position is
//       open with SL Mode = Dollar, that position is UNPROTECTED on the downside until the
//       bot resumes ticking. A broker pip stop would survive such an outage; a dollar stop
//       does not.
//     * In the Dollar-SL + Pips-TP mix the protection is ASYMMETRIC: the broker still holds
//       the upside pip TP (it survives an outage), but the downside dollar SL depends on
//       the bot being alive. This asymmetry is inherent to monitoring net P&L in-process
//       and is intended, not a bug.
//   If broker-guaranteed downside protection is required, use SL Mode = Pips instead.
//
// DELIBERATELY DROPPED (per explicit user instruction "dont add projection"):
//   - The Pine version drew permanent TP-zone / SL-zone rectangles and a dotted entry
//     line for every placed order, plus structure lines/labels and the FVG boxes.
//   - NONE of that trade-projection / structure drawing is ported. The ONLY chart
//     drawing here is the stats dashboard via Chart.DrawStaticText.
//
// -------------------------------------------------------------------------------------
// INDEXING / TIMING CONVENTION (read this before tracing the logic):
//
//   * OnBar fires at the OPEN of a NEW bar. At that moment the bar that just finished
//     forming is the "just-closed confirmed bar". In cAlgo that bar is Bars.*.Last(1)
//     (Last(0) is the brand-new, still-forming bar).
//   * Pine evaluates the strategy on bar close, referencing history as high[k] where
//     high[0] is the (closed) current bar and high[k] is k bars before it.
//   * To match Pine "confirmed on close", we treat the just-closed bar (Last(1)) as the
//     Pine "current" bar. So the Pine offset k maps to cAlgo Last(k + 1):
//         Pine  high[k]   ->  Bars.HighPrices.Last(k + 1)
//         Pine  close     ->  Bars.ClosePrices.Last(1)      (close[0])
//         Pine  close[1]  ->  Bars.ClosePrices.Last(2)
//     The helper accessors H(k)/L(k)/C(k)/O(k) below encapsulate this (+1) shift, so
//     inside the ported functions the index k reads exactly like the Pine [k].
//   * "Bar index" of the just-closed bar is CurrentBarIndex == Bars.Count - 2
//     (Last(1)). Pivot bar indices are stored on this same scale so span math matches
//     the Pine bar_index arithmetic.
//
//   ta.crossover(close, level)  = close[1] <= level && close[0] > level
//                               -> C(1) <= level && C(0) > level   (evaluated at close)
//   ta.crossunder(close, level) = close[1] >= level && close[0] < level
//                               -> C(1) >= level && C(0) < level
// =====================================================================================

using System;
using System.Linq;
using System.Text;
using cAlgo.API;
using cAlgo.API.Internals;

namespace cAlgo.Robots
{
    // ---------------------------------------------------------------------------------
    // Enums exposed as parameters (mirror the Pine input.string option groups).
    // ---------------------------------------------------------------------------------

    // Pine: structFvgSourceInput options [Internal, Swing, Both]. This is the SINGLE
    // source of truth that gates trade placement per structure type (Pine bullMakeFvg /
    // bearMakeFvg). No FVG in the leg => no order.
    public enum FvgSource
    {
        Internal,
        Swing,
        Both
    }

    // Pine: entryModeInput options [Limit, Market].
    public enum EntryMode
    {
        Limit,
        Market
    }

    // Pine: entryFibInput options ['0','0.25','0.5','0.75','1']. Enum selection maps to
    // the numeric fib level in FibLevel().
    public enum EntryFib
    {
        Fib0,
        Fib025,
        Fib05,
        Fib075,
        Fib1
    }

    // Pine: tpModeInput options [Points, RRR]. Expanded with a Dollar option:
    //   Pips   = fixed take-profit distance in pips, attached to the broker order.
    //   RRR    = reward:risk multiple. If SL Mode = Pips the broker TP distance is
    //            Rrr * StopLossPips (broker-attached); if SL Mode = Dollar the target
    //            is Rrr * StopLossDollars and is monitored as a net-P&L threshold.
    //   Dollar = target expressed in account/deposit currency; NO broker TP is
    //            attached, the bot closes the position from OnTick when its net P&L
    //            reaches TakeProfitDollars.
    // NOTE: the old member `Points` was renamed to `Pips` for wording consistency with
    // the new SL Mode / Stop Loss (pips) parameters; all references were updated.
    public enum TpMode
    {
        Pips,
        RRR,
        Dollar
    }

    // How a stop-loss / take-profit magnitude is expressed and enforced:
    //   Pips   = a broker stop distance in pips attached to the order at placement
    //            time (the broker/server manages that dimension).
    //   Dollar = a net-P&L threshold in the account/deposit currency (usually USD);
    //            NO broker stop is attached for that dimension. The bot monitors each
    //            of its OWN open positions on every tick (OnTick) via Position.NetProfit
    //            and closes a position once the threshold is crossed.
    public enum RiskUnit
    {
        Pips,
        Dollar
    }

    [Robot(AccessRights = AccessRights.None, TimeZone = TimeZones.UTC)]
    public class SmcFvgBot : Robot
    {
        // -----------------------------------------------------------------------------
        // PARAMETERS (mirror the Pine inputs; unit changes are flagged where relevant).
        // -----------------------------------------------------------------------------

        // Pine: swingsLengthInput (int, default 50, minval 10). Swing structure size.
        [Parameter("Swing Length", DefaultValue = 50, MinValue = 10, Group = "Structure")]
        public int SwingLength { get; set; }

        // Pine: structFvgSourceInput. Single gate for enabling trades per structure type.
        [Parameter("Apply FVG To", DefaultValue = FvgSource.Internal, Group = "Structure")]
        public FvgSource FvgApplyTo { get; set; }

        // Pine: entryModeInput. Limit = pending order at fib level; Market = at close.
        [Parameter("Entry Mode", DefaultValue = EntryMode.Limit, Group = "Entry")]
        public EntryMode Entry { get; set; }

        // Pine: entryFibInput. Where inside the FVG the limit entry sits (near->far edge).
        [Parameter("Entry Fib Level", DefaultValue = EntryFib.Fib0, Group = "Entry")]
        public EntryFib Fib { get; set; }

        // How the stop-loss is expressed/enforced: Pips = broker stop distance (server
        // managed); Dollar = net-P&L threshold monitored per-position in OnTick. Default
        // Pips preserves the pre-change broker-stop behavior.
        // TRADE-OFF: a Dollar SL attaches NO broker stop and is only enforced while the bot
        // is running (see the "DOLLAR SL/TP TRADE-OFF" note in the file header). If the bot
        // stops/disconnects, a Dollar-SL position is unprotected on the downside.
        [Parameter("SL Mode", DefaultValue = RiskUnit.Pips, Group = "Risk")]
        public RiskUnit SlMode { get; set; }

        // Pine: slPointsInput (default 300 in RAW PRICE POINTS).
        // UNIT CHANGE: cAlgo order calls take a stop-loss distance in PIPS, so the numeric
        // default changes to a pip-appropriate value (30 pips), NOT 300 raw price points.
        // Used only when SL Mode = Pips.
        [Parameter("Stop Loss (pips)", DefaultValue = 30, MinValue = 0, Group = "Risk")]
        public double StopLossPips { get; set; }

        // Dollar stop distance in the account/deposit currency (usually USD). Used only
        // when SL Mode = Dollar: OnTick closes an own position when its Position.NetProfit
        // (which already includes commission + swap) is <= -(StopLossDollars). MinValue 0;
        // a value <= 0 disables the dollar SL check (no instant close).
        [Parameter("Stop Loss ($)", DefaultValue = 10, MinValue = 0, Group = "Risk")]
        public double StopLossDollars { get; set; }

        // Pine: tpModeInput. Pips = fixed broker TP distance; RRR = Rrr x SL distance
        // (broker-attached when SL Mode = Pips, else dollar-monitored); Dollar = net-P&L
        // target monitored per-position in OnTick.
        [Parameter("TP Mode", DefaultValue = TpMode.Pips, Group = "Risk")]
        public TpMode TakeProfitMode { get; set; }

        // Pine: tpPointsInput (default 5000 in RAW PRICE POINTS).
        // UNIT CHANGE: now expressed in PIPS, so the numeric default changes to 500 pips,
        // NOT 5000 raw price points. Used only when TP Mode = Pips.
        [Parameter("Take Profit (pips)", DefaultValue = 500, MinValue = 0, Group = "Risk")]
        public double TakeProfitPips { get; set; }

        // Dollar take-profit target in the account/deposit currency. Used only when
        // TP Mode = Dollar: OnTick closes an own position when its Position.NetProfit is
        // >= TakeProfitDollars. MinValue 0; a value <= 0 disables the dollar TP check.
        [Parameter("Take Profit ($)", DefaultValue = 30, MinValue = 0, Group = "Risk")]
        public double TakeProfitDollars { get; set; }

        // BASKET take-profit toggle. When enabled, OnTick sums Position.NetProfit across
        // ALL of this bot's own open positions and, when the combined net reaches
        // BasketTakeProfitDollars, closes EVERY own position at once. This is independent
        // of the per-position dollar SL/TP above and runs regardless of SL Mode / TP Mode
        // (including pip-only mode). Pending limit orders are left untouched. Default off,
        // so the bot behaves exactly as before unless the user enables it.
        [Parameter("Use Basket TP", DefaultValue = false, Group = "Risk")]
        public bool UseBasketTp { get; set; }

        // Basket take-profit target in the account/deposit currency (usually USD),
        // compared against the SUM of Position.NetProfit (net incl. commission + swap)
        // over the bot's own open positions. Used only when Use Basket TP = true.
        // MinValue 0; a value <= 0 disables the basket check.
        [Parameter("Basket Take Profit ($)", DefaultValue = 100, MinValue = 0, Group = "Risk")]
        public double BasketTakeProfitDollars { get; set; }

        // Pine: rrrInput (default 3, minval 0). Used only when TP Mode = RRR. Multiplies
        // StopLossPips (broker TP, when SL Mode = Pips) or StopLossDollars (dollar target
        // monitored in OnTick, when SL Mode = Dollar).
        [Parameter("Reward:Risk (RRR)", DefaultValue = 3, MinValue = 0, Group = "Risk")]
        public double Rrr { get; set; }

        // Pine: orderQtyInput (contracts). Sizing choice: expose Quantity in LOTS and
        // convert to volume-in-units via Symbol.QuantityToVolumeInUnits, then normalize
        // with Symbol.NormalizeVolumeInUnits so the volume is always broker-valid. This
        // is the idiomatic cAlgo approach (Pine's raw "contracts" has no direct analogue).
        [Parameter("Quantity (lots)", DefaultValue = 1, MinValue = 0.01, Step = 0.01, Group = "Risk")]
        public double Quantity { get; set; }

        // Pine: maxOrdersInput (default 100, minval 1). Concurrent-order cap.
        [Parameter("Max Concurrent Orders", DefaultValue = 100, MinValue = 1, Group = "Risk")]
        public int MaxConcurrentOrders { get; set; }

        // Pine: showDashboardInput (default true).
        [Parameter("Show Dashboard", DefaultValue = true, Group = "Dashboard")]
        public bool ShowDashboard { get; set; }

        // -----------------------------------------------------------------------------
        // CONSTANTS
        // -----------------------------------------------------------------------------

        // Pine trend bias constants: BULLISH = +1, BEARISH = -1, 0 = none.
        private const int BULLISH = +1;
        private const int BEARISH = -1;

        // Pine leg constants.
        private const int BULLISH_LEG = 1;
        private const int BEARISH_LEG = 0;

        // Pine internal structure size is HARD-CODED to 5 (getCurrentStructure(5,...)).
        // We keep that fixed choice; only the SWING size is user-configurable (SwingLength).
        private const int InternalStructureSize = 5;

        // Pine FVG scan look-back cap (math.min(bar_index - pivotBar, 300)).
        private const int FvgScanCap = 300;

        // Label prefix used to tag every order this bot places, so PendingOrders /
        // Positions / History can be filtered to THIS bot's own trades only (for the cap
        // and the dashboard stats). Each order gets prefix + incrementing counter.
        private const string BotLabelPrefix = "SmcFvg_";

        // Object name for the single dashboard static-text object.
        private const string DashboardObjectName = "SmcFvgDashboard";

        // -----------------------------------------------------------------------------
        // PERSISTENT STATE FIELDS
        // (Pine `var` pivots/trends/legs are per-bar-persistent; these must be fields,
        //  NOT locals, so the state machine survives across OnBar calls.)
        // -----------------------------------------------------------------------------

        // Pine: var pivot swingHigh/swingLow/internalHigh/internalLow.
        private Pivot _swingHigh;
        private Pivot _swingLow;
        private Pivot _internalHigh;
        private Pivot _internalLow;

        // Pine: var trend swingTrend / internalTrend (.bias).
        private int _swingTrendBias;
        private int _internalTrendBias;

        // Pine: leg() has `var leg = 0` PER CALL SITE. There are two call sites
        // (swing size and internal size 5), each with its own persisted leg value.
        // We also persist the PREVIOUS leg value per site to reproduce ta.change(leg).
        private int _swingLeg;
        private int _swingLegPrev;
        private bool _swingLegInit;

        private int _internalLeg;
        private int _internalLegPrev;
        private bool _internalLegInit;

        // Per-order unique-label counter.
        private int _orderCounter;

        // -----------------------------------------------------------------------------
        // Pivot: Pine `type pivot` (currentLevel, lastLevel, crossed, barIndex).
        // barTime is dropped (cAlgo does not need it; barIndex on the Last(1) scale is
        // sufficient for the FVG span math). currentLevel uses NaN for Pine `na`.
        // -----------------------------------------------------------------------------
        private class Pivot
        {
            public double CurrentLevel = double.NaN;
            public double LastLevel = double.NaN;
            public bool Crossed = false;
            public int BarIndex = 0;
        }

        // Result of an FVG scan (replaces the Pine structFvg push + size-changed check).
        private struct FvgResult
        {
            public bool Found;
            public double Top;    // price-ordered outer bound (max)
            public double Bottom; // price-ordered outer bound (min)
        }

        // =============================================================================
        // LIFECYCLE
        // =============================================================================

        protected override void OnStart()
        {
            // Initialize the persistent structure/trend/leg state (Pine var initializers).
            _swingHigh = new Pivot();
            _swingLow = new Pivot();
            _internalHigh = new Pivot();
            _internalLow = new Pivot();

            _swingTrendBias = 0;
            _internalTrendBias = 0;

            _swingLeg = 0;
            _swingLegPrev = 0;
            _swingLegInit = false;

            _internalLeg = 0;
            _internalLegPrev = 0;
            _internalLegInit = false;

            _orderCounter = 0;

            // ----- startup configuration warnings (review issue #3) -----
            // These are WARNINGS ONLY; they never change the exit logic. Print(...) is the
            // standard cAlgo Robot API logging call (writes to the cBot Log tab).
            //
            // A Dollar SL left at <= 0 means NO broker stop is attached (SL Mode != Pips)
            // AND the OnTick dollar-SL check is skipped (guarded by StopLossDollars > 0), so
            // the position has NO stop at all - silently. Surface it so the gap is visible.
            if (SlMode == RiskUnit.Dollar && StopLossDollars <= 0)
            {
                Print("WARNING: SL Mode = Dollar but Stop Loss ($) <= 0. No broker stop is "
                    + "attached and the dollar stop-loss check is disabled, so open "
                    + "positions have NO stop-loss protection. Set Stop Loss ($) > 0 to "
                    + "enable the dollar stop, or switch SL Mode to Pips for a broker stop.");
            }

            // A dollar take-profit target that resolves to <= 0 disables the OnTick TP
            // check the same way. This covers TP Mode = Dollar with Take Profit ($) <= 0,
            // and TP Mode = RRR off a Dollar SL where Rrr * StopLossDollars resolves to 0.
            bool dollarTpAtStart = TakeProfitMode == TpMode.Dollar
                || (TakeProfitMode == TpMode.RRR && SlMode == RiskUnit.Dollar);
            if (dollarTpAtStart)
            {
                double tpTarget = TakeProfitMode == TpMode.Dollar
                    ? TakeProfitDollars
                    : Rrr * StopLossDollars;
                if (tpTarget <= 0)
                {
                    Print("WARNING: the dollar take-profit target resolves to <= 0 "
                        + "(TP Mode = Dollar with Take Profit ($) <= 0, or TP Mode = RRR "
                        + "off a Dollar SL with Rrr * Stop Loss ($) <= 0). The dollar "
                        + "take-profit check is disabled and no broker target is attached.");
                }
            }

            // Basket TP enabled but the target resolves to <= 0 disables the basket check
            // (guarded by BasketTakeProfitDollars > 0 in OnTick). Surface it so the gap is
            // visible; this warning never changes behavior.
            if (UseBasketTp && BasketTakeProfitDollars <= 0)
            {
                Print("WARNING: Use Basket TP is enabled but Basket Take Profit ($) <= 0. "
                    + "The basket take-profit check is disabled. Set Basket Take Profit ($) "
                    + "> 0 to enable it, or turn off Use Basket TP.");
            }
        }

        // OnBar fires at the OPEN of a new bar => the just-closed bar is Last(1).
        // Execution order mirrors the Pine global scope:
        //   getCurrentStructure(swingsLengthInput,false)  -> swing pivots
        //   getCurrentStructure(5,false,true)             -> internal pivots
        //   displayStructure(true)  (internal)            -> breaks + orders
        //   displayStructure(false) (swing)               -> breaks + orders
        //   dashboard render
        // (Pine's maintainStructFvgs / pruneTradeOrders are NOT needed: cAlgo tracks
        //  pending orders and positions natively, and there is no FVG drawing to maintain.)
        protected override void OnBar()
        {
            // Need at least enough closed history to evaluate the largest look-back
            // (swing size + 2 for the crossover of close[1], plus the Last(1) shift).
            int needed = Math.Max(SwingLength, InternalStructureSize) + 3;
            if (Bars.ClosePrices.Count < needed)
                return;

            // ----- structure detection (order matches Pine) -----
            GetCurrentStructure(SwingLength, isInternal: false);
            GetCurrentStructure(InternalStructureSize, isInternal: true);

            DisplayStructure(isInternal: true);
            DisplayStructure(isInternal: false);

            // ----- dashboard -----
            if (ShowDashboard)
                UpdateDashboard();
        }

        // OnTick fires on every incoming price update. It enforces the DOLLAR-based
        // SL/TP dimensions only; the pip-based dimensions are attached to the broker order
        // in PlaceStrategyOrder and are managed server-side, so OnTick never touches them
        // (no double-close). Entries remain on bar close (OnBar); this method only exits.
        //
        // NOTES:
        //   * "Dollar" means the account/deposit currency (usually USD). Position.NetProfit
        //     is that currency's net P&L and ALREADY includes commission + swap.
        //   * Only THIS bot's own positions are monitored, filtered individually by the
        //     BotLabelPrefix label, each evaluated on its own NetProfit.
        //   * Current global parameter values are applied at tick time (SL Mode / TP Mode /
        //     dollar thresholds are read live, not stored per-position). Settings are not
        //     expected to change mid-run. Acceptable edge case: if the user changes these
        //     inputs and restarts while a position is open, the new thresholds apply to the
        //     already-open position on the next tick.
        //   * A materialized snapshot (ToList) is iterated so closing a position does not
        //     mutate the collection being enumerated.
        //   * PROCESS-LIVENESS DEPENDENCY (review issues #1/#2): because dollar dimensions
        //     attach no broker stop, they are enforced ONLY here, i.e. only while the bot
        //     is running. A stopped/disconnected bot leaves Dollar-SL positions unprotected
        //     on the downside; in a Dollar-SL + Pips-TP mix the broker still holds the
        //     upside TP but the downside relies on this method firing. This is intentional
        //     per the user's design (no hidden broker stop). See the file-header trade-off
        //     note. The <=0 threshold guards below (StopLossDollars > 0 / target > 0)
        //     disable the respective check; OnStart prints a warning when that leaves a
        //     dollar dimension silently off (review issue #3).
        protected override void OnTick()
        {
            // ----- BASKET take-profit -----
            // Independent of the per-position dollar SL/TP below. It must run even in
            // pip-only mode, so it is placed BEFORE the "no dollar dimension active"
            // early-return. When the COMBINED net P&L of all the bot's own open positions
            // reaches BasketTakeProfitDollars, close EVERY own position. Pending limit
            // orders are LEFT ALONE; the bot keeps detecting setups and placing orders.
            if (UseBasketTp && BasketTakeProfitDollars > 0)
            {
                // Snapshot of THIS bot's own open positions (by label prefix). Iterating
                // this materialized list means closing during the loop does not mutate the
                // live Positions collection being enumerated.
                var own = Positions
                    .Where(p => p.Label != null && p.Label.StartsWith(BotLabelPrefix))
                    .ToList();

                if (own.Count > 0)
                {
                    // Basket net = sum of net P&L (already incl. commission + swap) in the
                    // account/deposit currency across the bot's own open positions.
                    double basketNet = own.Sum(p => p.NetProfit);
                    if (basketNet >= BasketTakeProfitDollars)
                    {
                        foreach (var position in own)
                            position.Close(); // alternative: ClosePosition(position);
                        return; // basket closed everything this tick; skip per-position loop.
                    }
                }
            }

            // Nothing to monitor unless at least one dollar dimension is active.
            bool dollarSl = SlMode == RiskUnit.Dollar;
            bool dollarTp = TakeProfitMode == TpMode.Dollar
                || (TakeProfitMode == TpMode.RRR && SlMode == RiskUnit.Dollar);
            if (!dollarSl && !dollarTp)
                return;

            // Snapshot of THIS bot's own open positions (by label prefix).
            var ownPositions = Positions
                .Where(p => p.Label != null && p.Label.StartsWith(BotLabelPrefix))
                .ToList();

            foreach (var position in ownPositions)
            {
                // ----- dollar STOP-LOSS: close when net P&L <= -(StopLossDollars) -----
                // Active only when SL Mode = Dollar; a threshold <= 0 disables the check
                // so a 0-dollar stop does not trigger an immediate close.
                if (dollarSl && StopLossDollars > 0
                    && position.NetProfit <= -StopLossDollars)
                {
                    position.Close(); // alternative: ClosePosition(position);
                    continue;         // closed; skip the TP check for this position.
                }

                // ----- dollar TAKE-PROFIT: close when net P&L >= target -----
                // Active when TP Mode = Dollar, or TP Mode = RRR with a dollar SL (target
                // = Rrr * StopLossDollars). A target <= 0 disables the check.
                if (dollarTp)
                {
                    double target = TakeProfitMode == TpMode.Dollar
                        ? TakeProfitDollars
                        : Rrr * StopLossDollars;
                    if (target > 0 && position.NetProfit >= target)
                    {
                        position.Close(); // alternative: ClosePosition(position);
                        continue;
                    }
                }
            }
        }

        protected override void OnStop()
        {
            // Optional cleanup: remove the dashboard text object if present.
            Chart.RemoveObject(DashboardObjectName);
        }

        // =============================================================================
        // INDEXING HELPERS
        // Encapsulate the (+1) shift so index k reads like the Pine [k] (k = 0 is the
        // just-closed bar). See the header timing convention.
        // =============================================================================

        private double H(int k) => Bars.HighPrices.Last(k + 1);
        private double L(int k) => Bars.LowPrices.Last(k + 1);
        private double C(int k) => Bars.ClosePrices.Last(k + 1);
        private double O(int k) => Bars.OpenPrices.Last(k + 1);

        // Bar index of the just-closed bar (Pine `bar_index` on close). Last(1) => Count-2.
        private int CurrentBarIndex => Bars.Count - 2;

        // ta.highest(size) over the `size` most recent CLOSED bars, EXCLUDING the just
        // closed bar's own [size]-back sample. Pine's ta.highest(size) at the current bar
        // covers high[0..size-1]. In leg(size) it is compared against high[size]; so we
        // need the highest of high[0..size-1] i.e. offsets 0..size-1.
        private double HighestExclusive(int size)
        {
            double m = double.NegativeInfinity;
            for (int k = 0; k <= size - 1; k++)
            {
                double v = H(k);
                if (v > m) m = v;
            }
            return m;
        }

        private double LowestExclusive(int size)
        {
            double m = double.PositiveInfinity;
            for (int k = 0; k <= size - 1; k++)
            {
                double v = L(k);
                if (v < m) m = v;
            }
            return m;
        }

        // =============================================================================
        // leg(size)  (Pine)
        // newLegHigh = high[size] > ta.highest(size)  -> leg := BEARISH_LEG
        // newLegLow  = low[size]  < ta.lowest(size)   -> leg := BULLISH_LEG
        // The leg value PERSISTS between bars (Pine `var leg = 0`), so each call site
        // keeps its own persisted value. Returns the updated leg for `size`.
        // =============================================================================
        private int Leg(int size, bool isInternal)
        {
            bool newLegHigh = H(size) > HighestExclusive(size);
            bool newLegLow = L(size) < LowestExclusive(size);

            if (isInternal)
            {
                if (newLegHigh) _internalLeg = BEARISH_LEG;
                else if (newLegLow) _internalLeg = BULLISH_LEG;
                return _internalLeg;
            }
            else
            {
                if (newLegHigh) _swingLeg = BEARISH_LEG;
                else if (newLegLow) _swingLeg = BULLISH_LEG;
                return _swingLeg;
            }
        }

        // Pine ta.change(leg): difference between this bar's leg and the previous bar's.
        // startOfNewLeg     => change != 0
        // startOfBullishLeg => change == +1  (leg went 0 -> 1)  => new pivot LOW
        // startOfBearishLeg => change == -1  (leg went 1 -> 0)  => new pivot HIGH
        // We compute the change from the per-site persisted previous value, then store
        // the current as previous for the next bar (done inside GetCurrentStructure).

        // =============================================================================
        // getCurrentStructure(size, internal)  (Pine)
        // Updates the correct pivot when a new leg starts. On a new BULLISH leg (pivotLow)
        // update the LOW pivot with low[size]; on a new BEARISH leg (pivotHigh) update the
        // HIGH pivot with high[size]. barIndex = current bar index - size.
        // (The Pine swing-point label drawing is intentionally dropped.)
        // =============================================================================
        private void GetCurrentStructure(int size, bool isInternal)
        {
            int currentLeg = Leg(size, isInternal);

            // ta.change(leg) using per-site previous value.
            int change;
            if (isInternal)
            {
                change = _internalLegInit ? currentLeg - _internalLegPrev : 0;
                _internalLegPrev = currentLeg;
                _internalLegInit = true;
            }
            else
            {
                change = _swingLegInit ? currentLeg - _swingLegPrev : 0;
                _swingLegPrev = currentLeg;
                _swingLegInit = true;
            }

            bool newPivot = change != 0;
            if (!newPivot)
                return;

            bool pivotLow = change == +1;  // startOfBullishLeg
            // else pivotHigh (change == -1)

            if (pivotLow)
            {
                Pivot p = isInternal ? _internalLow : _swingLow;
                p.LastLevel = p.CurrentLevel;
                p.CurrentLevel = L(size);
                p.Crossed = false;
                p.BarIndex = CurrentBarIndex - size;
            }
            else
            {
                Pivot p = isInternal ? _internalHigh : _swingHigh;
                p.LastLevel = p.CurrentLevel;
                p.CurrentLevel = H(size);
                p.Crossed = false;
                p.BarIndex = CurrentBarIndex - size;
            }
        }

        // =============================================================================
        // displayStructure(internal)  (Pine)
        // Detects bullish break = crossover(close, pivotHigh.currentLevel) && !crossed,
        // and bearish break = crossunder(close, pivotLow.currentLevel) && !crossed, on the
        // just-closed bar. On a break: set the tag (BOS vs CHoCH by prior bias), flip the
        // pivot.crossed flag, set trend bias, and IF the FvgSource gate enables this
        // structure type, scan for the last same-direction FVG in the leg and place ONE
        // order for it. The FvgSource enum is the SINGLE gate (Pine bullMakeFvg/bearMakeFvg).
        // (Pine's confluence filter, structure line/label drawing and alerts are dropped;
        //  the trade-relevant control flow is preserved exactly.)
        // =============================================================================
        private void DisplayStructure(bool isInternal)
        {
            // Pine extraCondition:
            //   internal ? internalHigh.currentLevel != swingHigh.currentLevel and bullishBar : true   (bull branch)
            //   internal ? internalLow.currentLevel  != swingLow.currentLevel  and bearishBar : true   (bear branch)
            // The confluence input (bullishBar/bearishBar) is NOT ported and defaults to
            // true, so the only surviving gate is the pivot-level inequality on INTERNAL
            // breaks: an internal break (and its order) is suppressed when the internal
            // pivot level exactly equals the corresponding swing pivot level. Swing
            // breaks keep extraCondition = true. In Pine this gate sits on the whole
            // `if` block (before bullMakeFvg / order placement), so we place it on the
            // internal-branch guard here, suppressing the crossed flip, trend flip, FVG
            // scan and order alike. See smc_fvg_strategy.pine lines 485/488, 516/519.

            // ----- BULLISH break: crossover(close, high pivot) -----
            Pivot pHigh = isInternal ? _internalHigh : _swingHigh;
            int trendBias = isInternal ? _internalTrendBias : _swingTrendBias;

            // Pine `a != na` evaluates to `na` (falsy), so when the swing pivot is unset
            // (NaN) the internal extraCondition is falsy and suppresses the break. We
            // reproduce that: require the swing level to be a real number AND differ.
            bool bullExtraCondition = !isInternal
                || (!double.IsNaN(_swingHigh.CurrentLevel)
                    && pHigh.CurrentLevel != _swingHigh.CurrentLevel);

            if (!double.IsNaN(pHigh.CurrentLevel)
                && Crossover(pHigh.CurrentLevel)
                && !pHigh.Crossed
                && bullExtraCondition)
            {
                // tag only affects Pine's (dropped) drawing; retained for clarity/parity.
                // bool isChoch = trendBias == BEARISH;

                pHigh.Crossed = true;
                trendBias = BULLISH;
                if (isInternal) _internalTrendBias = trendBias; else _swingTrendBias = trendBias;

                // Single gate: does the FvgSource enable THIS structure type?
                if (FvgGateEnabled(isInternal))
                {
                    FvgResult f = HighlightStructFvg(pHigh.BarIndex, isBull: true);
                    if (f.Found)
                        // Long: near edge = FVG top, far edge = FVG bottom.
                        PlaceStrategyOrder(isBull: true, nearEdge: f.Top, farEdge: f.Bottom);
                }
            }

            // ----- BEARISH break: crossunder(close, low pivot) -----
            Pivot pLow = isInternal ? _internalLow : _swingLow;
            trendBias = isInternal ? _internalTrendBias : _swingTrendBias;

            // Same Pine `a != na` -> falsy handling as the bull branch above.
            bool bearExtraCondition = !isInternal
                || (!double.IsNaN(_swingLow.CurrentLevel)
                    && pLow.CurrentLevel != _swingLow.CurrentLevel);

            if (!double.IsNaN(pLow.CurrentLevel)
                && Crossunder(pLow.CurrentLevel)
                && !pLow.Crossed
                && bearExtraCondition)
            {
                // bool isChoch = trendBias == BULLISH;

                pLow.Crossed = true;
                trendBias = BEARISH;
                if (isInternal) _internalTrendBias = trendBias; else _swingTrendBias = trendBias;

                if (FvgGateEnabled(isInternal))
                {
                    FvgResult f = HighlightStructFvg(pLow.BarIndex, isBull: false);
                    if (f.Found)
                        // Short: near edge = FVG bottom, far edge = FVG top.
                        PlaceStrategyOrder(isBull: false, nearEdge: f.Bottom, farEdge: f.Top);
                }
            }
        }

        // Pine bullMakeFvg / bearMakeFvg gate, reduced to its trade-relevant core:
        //   internal break enabled when FvgSource == Internal || Both
        //   swing    break enabled when FvgSource == Swing    || Both
        private bool FvgGateEnabled(bool isInternal)
        {
            if (isInternal)
                return FvgApplyTo == FvgSource.Internal || FvgApplyTo == FvgSource.Both;
            return FvgApplyTo == FvgSource.Swing || FvgApplyTo == FvgSource.Both;
        }

        // ta.crossover(close, level): close[1] <= level && close[0] > level.
        private bool Crossover(double level) => C(1) <= level && C(0) > level;

        // ta.crossunder(close, level): close[1] >= level && close[0] < level.
        private bool Crossunder(double level) => C(1) >= level && C(0) < level;

        // =============================================================================
        // highlightStructFvg(pivotBarIndex, isBull)  (Pine)
        // Scans the break leg from the break bar backwards to the broken pivot for the
        // LAST (most recent) same-direction 3-candle FVG:
        //   bullish hit: low[k]  > high[k+2]
        //   bearish hit: high[k] < low[k+2]
        // Takes the FIRST hit found scanning k = 0..span-2 (most recent). Bounds are
        // price-ordered: bull t=low[found], b=high[found+2]; bear t=low[found+2],
        // b=high[found]; then top=max(t,b), bottom=min(t,b) (reproduces Pine exactly).
        // Returns Found + price-ordered Top/Bottom so the caller places ONE order only
        // when a FVG exists (Pine places exactly one order per confirmed break).
        // (Pine's box drawing is dropped; only the detection + bounds are kept.)
        // =============================================================================
        private FvgResult HighlightStructFvg(int pivotBarIndex, bool isBull)
        {
            var result = new FvgResult { Found = false };

            // span = min(bar_index - pivotBar, 300) bars back to the pivot.
            int span = Math.Min(CurrentBarIndex - pivotBarIndex, FvgScanCap);
            if (span < 2)
                return result;

            int found = -1;
            for (int k = 0; k <= span - 2; k++)
            {
                bool hit = isBull ? (L(k) > H(k + 2)) : (H(k) < L(k + 2));
                if (found == -1 && hit)
                {
                    found = k;
                    break; // first (most recent) hit only
                }
            }

            if (found == -1)
                return result;

            double t = isBull ? L(found) : L(found + 2);
            double b = isBull ? H(found + 2) : H(found);

            result.Found = true;
            result.Top = Math.Max(t, b);
            result.Bottom = Math.Min(t, b);
            return result;
        }

        // =============================================================================
        // placeStrategyOrder(isBull, nearEdge, farEdge)  (Pine)
        // Cap guard FIRST: count THIS bot's own live orders (pending + positions filtered
        // by label prefix); if >= MaxConcurrentOrders, skip. Entry:
        //   Market => at just-closed close (fib ignored)  -> ExecuteMarketOrder
        //   Limit  => nearEdge + fib*(farEdge-nearEdge)   -> PlaceLimitOrder, NO expiry
        // SL and TP are attached to the broker order ONLY for their pip-based dimensions;
        // dollar-based dimensions get NO broker stop/target here and are instead managed
        // per-position from OnTick (see the SL/TP-in-pips block below and OnTick).
        // A unique label BotLabelPrefix + counter is attached to every order so the cap
        // and the dashboard can filter to this bot's own trades.
        // (Pine's projection boxes/lines are intentionally NOT created.)
        // =============================================================================
        private void PlaceStrategyOrder(bool isBull, double nearEdge, double farEdge)
        {
            if (double.IsNaN(nearEdge) || double.IsNaN(farEdge))
                return;

            // ----- concurrent-order cap: only THIS bot's own live orders -----
            int ownLive =
                PendingOrders.Count(o => o.Label != null && o.Label.StartsWith(BotLabelPrefix))
                + Positions.Count(p => p.Label != null && p.Label.StartsWith(BotLabelPrefix));
            if (ownLive >= MaxConcurrentOrders)
                return;

            // ----- volume from Quantity (lots) -----
            double volume = Symbol.NormalizeVolumeInUnits(
                Symbol.QuantityToVolumeInUnits(Quantity), RoundingMode.Down);
            if (volume <= 0)
                return;

            // ----- SL / TP in PIPS (broker-attached dimensions only) -----
            // Broker SL and broker TP are computed INDEPENDENTLY; each is only attached
            // for its pip-based portion so mixed modes work (e.g. dollar SL + pip/RRR-pip
            // TP still gets its broker TP):
            //   * Broker SL pips = StopLossPips only when SL Mode = Pips; when SL Mode =
            //     Dollar no broker stop is attached (null) and OnTick enforces the dollar SL.
            //   * Broker TP pips:
            //       TP Mode = Pips                        -> TakeProfitPips
            //       TP Mode = RRR  AND  SL Mode = Pips    -> Rrr * StopLossPips
            //       TP Mode = Dollar, or TP Mode = RRR
            //         with SL Mode = Dollar               -> null (OnTick enforces the
            //                                                 dollar target instead)
            // Guard (review issue #4): the parameters retain Pine's `minval 0`, but in
            // cAlgo a 0-pip distance is a real 0-distance stop/target (which would close
            // the trade instantly), NOT "no stop/target". A 0 (or negative) pip magnitude
            // is therefore mapped to null = disabled, matching Pine's intent where 0 means
            // "off". The order overloads take nullable double? for SL/TP pips.
            double? rawSl = SlMode == RiskUnit.Pips ? StopLossPips : (double?)null;

            double? rawTp;
            if (TakeProfitMode == TpMode.Pips)
                rawTp = TakeProfitPips;
            else if (TakeProfitMode == TpMode.RRR && SlMode == RiskUnit.Pips)
                rawTp = Rrr * StopLossPips;
            else
                rawTp = null; // Dollar TP, or RRR TP off a dollar SL -> monitored in OnTick.

            double? slPips = rawSl.HasValue && rawSl.Value > 0 ? rawSl : (double?)null;
            double? tpPips = rawTp.HasValue && rawTp.Value > 0 ? rawTp : (double?)null;

            TradeType tradeType = isBull ? TradeType.Buy : TradeType.Sell;
            string label = BotLabelPrefix + (++_orderCounter);

            if (Entry == EntryMode.Market)
            {
                // Market entry: enter immediately at the just-closed close (fib ignored).
                // Overload assumed present in current cAlgo API:
                //   ExecuteMarketOrder(TradeType, symbolName, volume, label, stopLossPips, takeProfitPips)
                ExecuteMarketOrder(tradeType, SymbolName, volume, label, slPips, tpPips);
            }
            else
            {
                // Limit entry at the selected fib level inside the FVG.
                //   long : near = FVG top,    far = FVG bottom (deeper = lower price)
                //   short: near = FVG bottom, far = FVG top    (deeper = higher price)
                double fib = FibLevel();
                double targetPrice = nearEdge + fib * (farEdge - nearEdge);
                targetPrice = Math.Round(targetPrice, Symbol.Digits);

                // Overload assumed present in current cAlgo API:
                //   PlaceLimitOrder(TradeType, symbolName, volume, targetPrice, label, stopLossPips, takeProfitPips)
                // No expiration argument => pending order stays open indefinitely (Pine
                // limit orders never expire on their own).
                PlaceLimitOrder(tradeType, SymbolName, volume, targetPrice, label, slPips, tpPips);
            }
        }

        // Pine entryFibInput -> numeric fib level.
        private double FibLevel()
        {
            switch (Fib)
            {
                case EntryFib.Fib0: return 0.0;
                case EntryFib.Fib025: return 0.25;
                case EntryFib.Fib05: return 0.5;
                case EntryFib.Fib075: return 0.75;
                case EntryFib.Fib1: return 1.0;
                default: return 0.0;
            }
        }

        // =============================================================================
        // DASHBOARD  (Pine dashboard stats -> on-chart text via Chart.DrawStaticText)
        // Stats are computed from History filtered to THIS bot's own trades (label prefix),
        // expressed in PIPS. Shown: Win Rate, Total Net Pips, Max Losing Streak, Max
        // Winning Streak, Total RRR. All in a single multi-line string, top-right.
        // (No table, no background fill, no projection - per user instruction.)
        //
        // DELIBERATE REINTERPRETATIONS (review issues #2 and #3, confirmed intentional):
        //   * UNIT (issue #2): Pine's "Total Points" sums raw-price (exit-entry)*sign.
        //     This port reports Total Net Pips = sum(HistoricalTrade.Pips) instead. The
        //     dashboard stats are intentionally expressed in PIPS via cAlgo's History
        //     (HistoricalTrade.Pips / .NetProfit), which is the broker-normalized unit;
        //     the label ("Total Net Pips") reflects the change. NOT reverted to raw price.
        //   * CLASSIFICATION (issue #3): win/loss for the streaks (and Win Rate) is keyed
        //     off HistoricalTrade.NetProfit sign (money, incl. commission/swap), matching
        //     Pine's closedtrades.profit basis; the pip magnitudes (Total Net Pips, and the
        //     won/lost sums behind Total RRR) come from HistoricalTrade.Pips. A trade with
        //     positive pips but negative net (fees) therefore counts as a loss for streaks
        //     yet still adds its positive pips to the net-pips total. This split (NetProfit
        //     for sign, Pips for magnitude) is intentional per the orchestrator's PIPS +
        //     History requirement, NOT a bug.
        // =============================================================================
        private void UpdateDashboard()
        {
            // Own closed trades in chronological order (History is oldest-first).
            var ownTrades = History
                .Where(t => t.Label != null && t.Label.StartsWith(BotLabelPrefix))
                .ToList();

            int totalClosed = ownTrades.Count;
            int wins = 0;
            double totalNetPips = 0.0;
            double wonPips = 0.0;   // sum of pips on winning trades
            double lostPips = 0.0;  // absolute sum of pips on losing trades

            int curWinStreak = 0, curLossStreak = 0;
            int maxWinStreak = 0, maxLossStreak = 0;

            foreach (var t in ownTrades)
            {
                totalNetPips += t.Pips;

                // Classify win/loss by NetProfit (Pine used closedtrades.profit sign).
                // Pips are used for the net-pips total and the RRR magnitudes.
                if (t.NetProfit > 0)
                {
                    wins++;
                    wonPips += t.Pips;
                    curWinStreak++;
                    curLossStreak = 0;
                    if (curWinStreak > maxWinStreak) maxWinStreak = curWinStreak;
                }
                else if (t.NetProfit < 0)
                {
                    lostPips += Math.Abs(t.Pips);
                    curLossStreak++;
                    curWinStreak = 0;
                    if (curLossStreak > maxLossStreak) maxLossStreak = curLossStreak;
                }
                // NetProfit == 0 (break-even) ignored for streaks.
            }

            // Win Rate = winning closed / total closed * 100 (guard /0 => n/a).
            string winRateStr = totalClosed > 0
                ? (wins / (double)totalClosed * 100.0).ToString("0.##") + "%"
                : "n/a";

            // Total RRR = sum(win pips) / abs(sum(loss pips)), profit-factor style;
            // n/a when there are no losses (guard divide-by-zero).
            string totalRrrStr = lostPips > 0
                ? (wonPips / lostPips).ToString("0.##")
                : "n/a";

            var sb = new StringBuilder();
            sb.AppendLine("SMC FVG Stats");
            sb.AppendLine("Win Rate: " + winRateStr);
            sb.AppendLine("Total Net Pips: " + totalNetPips.ToString("0.##"));
            sb.AppendLine("Max Losing Streak: " + maxLossStreak);
            sb.AppendLine("Max Winning Streak: " + maxWinStreak);
            sb.Append("Total RRR: " + totalRrrStr);

            // Single multi-line static text, top-right, legible color. DrawStaticText has
            // no background fill (kept simple, per the confirmed dashboard choice).
            Chart.DrawStaticText(
                DashboardObjectName,
                sb.ToString(),
                VerticalAlignment.Top,
                HorizontalAlignment.Right,
                Color.White);
        }
    }
}
