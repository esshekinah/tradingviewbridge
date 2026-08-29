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

Each line extends to the right until **its own level is mitigated** (touched by price), then it is **discontinued** — frozen at the bar where price reached it. The Top, CE, and Bottom of a single FVG are mitigated independently.

## Features

| Setting | Description |
|---|---|
| **Show 4H / 15M** | Toggle each timeframe independently |
| **Line colors** | Four independent color inputs — **4H Bullish (+)**, **4H Bearish (-)**, **15M Bullish (+)**, **15M Bearish (-)** — so each timeframe/direction can be styled separately (defaults: 4H white/red, 15M aqua/orange) |
| **Line width** | Thickness of the level lines |
| **Show Top / CE / Bottom line** | Toggle each of the three levels on/off |
| **Max FVGs per set** | Trims oldest FVGs to keep the chart clean |
| **Extend lines (bars)** | How far right each active level projects |
| **Show text labels** | Toggle the right-end labels; configurable **text size** (Tiny / Small / Normal / Large) and **font** (Default / Monospace — Pine Script only supports these two families; a true Arial is not available, but Default is TradingView's Arial-like sans-serif) |
| **Dashboard (color legend)** | An on-chart table (default top-right) showing what each line/marker color means — 4H bull/bear, 15M bull/bear, Buy/Sell signals, and the proximity arrow. Configurable position, text size, background and text color; can be toggled off |
| **Alerts** | Built-in `alertcondition` fires for new 4H / 15M FVGs and Buy/Sell signals |

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

## Proximity arrows

When any **4H level** (Top / CE / Bottom) sits within a configurable distance of any **same-direction 15M level**, a **red left-pointing arrow** is drawn at the midpoint price between the two close lines, pointing left toward them.

- **Arrow max distance (points)** — threshold in raw price points (default `4`).
- Only **same-direction** pairs are considered, and only when the 15M FVG formed during the 4H displacement window (same rule as the signals).
- The arrow is **removed automatically if either linked level is mitigated** — as soon as price touches the 4H level or the 15M level it connects, the arrow disappears.
- Color, width, and length (how far the tail extends to the right) are configurable.

## Notes

- Uses non-repainting `request.security` (`lookahead_off`), so gaps confirm only after the higher-timeframe candle closes — this avoids repainting and false signals.

## License

MIT
