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

## Confluence filter (15M inside 4H)

By default, the indicator only shows **15M FVGs that overlap a 4H FVG**. Overlap counts whether the 15M gap is *fully* inside the 4H zone or only *partly* inside it (two ranges overlap when each starts before the other ends).

- 4H zones are always tracked for the filter even if you hide them visually (turn off **Show 4H FVGs** but keep the confluence toggle on).
- When a 4H FVG gets mitigated, it stops qualifying as confluence for new 15M FVGs.
- Turn the toggle off to see all 15M FVGs regardless of 4H context.

## Notes

- Uses non-repainting `request.security` (`lookahead_off`), so gaps confirm only after the higher-timeframe candle closes — this avoids repainting and false signals.

## License

MIT
