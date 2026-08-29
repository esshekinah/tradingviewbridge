# Multi-TF FVG Indicator (4H + 15M)

A TradingView **Pine Script v5** indicator that detects **Fair Value Gaps (FVGs)** on the **4-hour** and **15-minute** timeframes and draws them on **any chart timeframe** you are currently viewing.

View a 1M or 5M chart and still see exactly where the higher-timeframe 4H and 15M gaps sit.

## What is a Fair Value Gap?

An FVG (a.k.a. imbalance) is a classic 3-candle pattern representing an untraded price range:

- **Bullish FVG** → `low[1] > high[3]` (gap between candle 1's low and candle 3's high)
- **Bearish FVG** → `high[1] < low[3]` (gap between candle 1's high and candle 3's low)

## Features

| Setting | Description |
|---|---|
| **Show 4H / 15M** | Toggle each timeframe independently |
| **Only 15M inside 4H (confluence)** | When enabled, a 15M FVG is drawn **only if any part of its range overlaps an active 4H FVG zone** — filtering for high-probability confluence setups |
| **Colors** | Separate bull/bear colors per timeframe for easy identification |
| **Max FVGs per set** | Trims oldest gaps to keep the chart clean |
| **Extend boxes** | How far right each gap box projects |
| **Remove when filled** | Auto-deletes a gap once price fully mitigates it |
| **Labels** | Tags each box as "4H Bull FVG", "15M Bear FVG", etc. |
| **Alerts** | Built-in `alertcondition` fires when a new 4H or 15M FVG forms |

The timeframes are configurable inputs, so you can repurpose the indicator for any two timeframes (e.g. Daily + 1H) without editing code.

## Installation

1. Open TradingView → **Pine Editor** (bottom panel).
2. Paste in the contents of [`multi_tf_fvg.pine`](./multi_tf_fvg.pine).
3. Click **Add to chart**.
4. Adjust colors/timeframes via the indicator settings (⚙️).

## Buy / Sell signals (formation-time confluence)

Each FVG has three levels: **Bottom**, **CE** (Consequent Encroachment = midpoint), and **Top**.

The signal is based on **when** a 15M FVG formed, not where price later goes. The rule:

1. Take the **4H displacement candle** — the middle candle whose large move created the 4H gap. Its time span is the "formation window".
2. A 15M FVG qualifies only if it **formed during that displacement candle** (its own displacement/middle-candle time falls inside the window). A 15M FVG that appears later — e.g. when price re-enters the zone — does **not** count.
3. Direction must match: a bullish 4H FVG only pairs with bullish 15M FVGs (and bearish with bearish).
4. Among qualifying 15M FVGs, compare the three levels (Bottom / CE / Top) against the 4H FVG's three levels — 9 line-to-line distance checks. If **any** pair is within the **Max line distance (price points)** threshold, a signal fires:
   - **BUY** (green ▲ below bar) for a bullish 4H + 15M pair
   - **SELL** (red ▼ above bar) for a bearish pair

### Signal timing

Because a 4H FVG is only confirmed once its third candle closes (~8 hours after the displacement candle), the signal is emitted **on 4H confirmation**, scanning back over the 15M FVGs that already formed inside the displacement window. This keeps the signal non-repainting — it appears at the earliest bar where the full pattern is actually known.

The threshold is measured in raw **price points** (e.g. `4.0` means 4.0 in the instrument's price), so set it to match the symbol's scale — for example a few points on an index like US Tech 100. Both signal colors are configurable, and alerts fire for BUY/SELL.

## Notes

- Uses non-repainting `request.security` (`lookahead_off`), so gaps confirm only after the higher-timeframe candle closes — this avoids repainting and false signals.

## License

MIT
