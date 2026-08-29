# Multi-TF FVG Indicator (4H + 15M)

A TradingView **Pine Script v5** indicator that detects **Fair Value Gaps (FVGs)** on the **4-hour** and **15-minute** timeframes and draws them on **any chart timeframe** you are currently viewing.

View a 1M or 5M chart and still see exactly where the higher-timeframe 4H and 15M gaps sit.

## What is a Fair Value Gap?

An FVG (a.k.a. imbalance) is a classic 3-candle pattern representing an untraded price range:

- **Bullish FVG** → `low[1] > high[3]` (gap between candle 1's low and candle 3's high)
- **Bearish FVG** → `high[1] < low[3]` (gap between candle 1's high and candle 3's low)

## How each FVG is drawn

Instead of a shaded rectangle, every FVG is drawn as **three horizontal lines** — **Top**, **CE** (midpoint), and **Bottom** — each with a text label at its right end:

```
+4H FVG Top      -4H FVG Top       +15M FVG Top      -15M FVG Top
+4H FVG CE       -4H FVG CE        +15M FVG CE       -15M FVG CE
+4H FVG Bottom   -4H FVG Bottom    +15M FVG Bottom   -15M FVG Bottom
```

- `+` = **bullish** FVG (drawn in **white** by default)
- `-` = **bearish** FVG (drawn in **red** by default)

Each line extends to the right until **its own level is mitigated**, then it is **discontinued** — frozen at the bar where price re-entered it. The Top, CE, and Bottom of a single FVG are mitigated independently.

**Mitigation is directional** — a level only counts as mitigated when price **re-enters the gap from the side it was left open**, not when the original impulse move created/extended it:

- **Bullish FVG** (gap below price) → filled from **above** (price drops back down into it)
- **Bearish FVG** (gap above price) → filled from **below** (price rallies back up into it)

**Wick / Body mode** (setting: *Mitigation by*) chooses what counts as reaching a level:

- **Wick** — the candle wick reaches the level (`high` / `low`)
- **Body** — the candle body reaches it (`max(open, close)` / `min(open, close)`)

## Features

| Setting | Description |
|---|---|
| **Show 4H / 15M** | Toggle each timeframe independently |
| **Line colors** | Four independent color inputs — **4H Bullish (+)**, **4H Bearish (-)**, **15M Bullish (+)**, **15M Bearish (-)** — so each timeframe/direction can be styled separately (defaults: 4H white/red, 15M aqua/orange) |
| **Line width** | Thickness of the level lines |
| **Show/Hide Lines** | Per-category visibility — Top, CE, and Bottom can each be toggled independently for **4H Bullish**, **4H Bearish**, **15M Bullish**, and **15M Bearish** (12 toggles total, grouped in settings) |
| **Max FVGs per set** | Trims oldest FVGs to keep the chart clean |
| **Extend lines (bars)** | How far right each active level projects |
| **Show text labels** | Toggle the right-end labels; configurable **text size** (Tiny / Small / Normal / Large) and **font** (Default / Monospace — Pine Script only supports these two families; a true Arial is not available, but Default is TradingView's Arial-like sans-serif) |
| **Dashboard (color legend)** | An on-chart table (default top-right) showing what each line/marker color means — 4H bull/bear, 15M bull/bear, and the proximity arrow. Configurable position, text size, background and text color; can be toggled off |
| **Alerts** | Built-in `alertcondition` fires for new 4H / 15M FVGs |

The timeframes are configurable inputs, so you can repurpose the indicator for any two timeframes (e.g. Daily + 1H) without editing code.

## Installation

1. Open TradingView → **Pine Editor** (bottom panel).
2. Paste in the contents of [`multi_tf_fvg.pine`](./multi_tf_fvg.pine).
3. Click **Add to chart**.
4. Adjust colors/timeframes via the indicator settings (⚙️).

## Proximity arrows

When any **4H level** (Top / CE / Bottom) sits within a configurable distance of any **same-direction 15M level**, a **red left-pointing arrow** is drawn at the midpoint price between the two close lines, pointing left toward them.

- **Arrow max distance (points)** — threshold in raw price points (default `4`).
- Only **same-direction** pairs are considered, and only when the 15M FVG formed during the 4H displacement window.
- The arrow is **removed automatically if either linked level is mitigated** — as soon as price touches the 4H level or the 15M level it connects, the arrow disappears.
- Color, width, and length (how far the tail extends to the right) are configurable.

## Notes

- Uses non-repainting `request.security` (`lookahead_off`), so gaps confirm only after the higher-timeframe candle closes — this avoids repainting and false signals.

## License

MIT
