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

## Notes

- Uses non-repainting `request.security` (`lookahead_off`), so gaps confirm only after the higher-timeframe candle closes — this avoids repainting and false signals.

## License

MIT
