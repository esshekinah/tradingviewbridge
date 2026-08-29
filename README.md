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

## Buy / Sell signals (level alignment)

Each FVG has three levels: **Bottom**, **CE** (Consequent Encroachment = midpoint), and **Top**.

When a new 15M FVG forms, the indicator compares its three levels against the three levels of every active 4H FVG **of the same direction** — 9 line-to-line distance checks per matching 4H FVG. If **any** 4H level sits within the configurable **Max line distance (price points)** of **any** 15M level, a signal is plotted:

- **BUY** (green ▲ below bar) when the bullish 15M FVG aligns with a bullish 4H FVG
- **SELL** (red ▼ above bar) when the bearish 15M FVG aligns with a bearish 4H FVG

The threshold is measured in raw **price points** (e.g. `4.0` means 4.0 in the instrument's price), so set it to match the symbol's scale — for example a few points on an index like US Tech 100. Both signal colors are configurable, and alerts fire for BUY/SELL.

## Confluence filter (15M inside 4H)

By default, the indicator only shows **15M FVGs that overlap a 4H FVG _of the same direction_**. Overlap counts whether the 15M gap is *fully* inside the 4H zone or only *partly* inside it (two ranges overlap when each starts before the other ends).

**Direction must match:** a bullish 4H FVG only pairs with bullish 15M FVGs, and a bearish 4H FVG only pairs with bearish 15M FVGs. Because both timeframes always agree on direction, signals map cleanly: bullish → **BUY**, bearish → **SELL**.

- 4H zones are always tracked for the filter even if you hide them visually (turn off **Show 4H FVGs** but keep the confluence toggle on).
- When a 4H FVG gets mitigated, it stops qualifying as confluence for new 15M FVGs.
- Turn the toggle off to see all 15M FVGs regardless of 4H context.

## Notes

- Uses non-repainting `request.security` (`lookahead_off`), so gaps confirm only after the higher-timeframe candle closes — this avoids repainting and false signals.

## License

MIT
