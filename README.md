# Bottom Top Tick | Emmanuel

A TradingView **Pine Script v5** indicator that detects **Fair Value Gaps (FVGs)** and **Order Blocks (OBs)** on the **Weekly**, **Daily**, **4-hour** and **15-minute** timeframes and draws them on **any chart timeframe** you are currently viewing.

View a 1M or 5M chart and still see exactly where the higher-timeframe gaps and order blocks sit.

## What is a Fair Value Gap?

An FVG (a.k.a. imbalance) is a classic 3-candle pattern representing an untraded price range:

- **Bullish FVG** → `low[1] > high[3]` (gap between candle 1's low and candle 3's high)
- **Bearish FVG** → `high[1] < low[3]` (gap between candle 1's high and candle 3's low)

## What is an Order Block?

An OB is the last opposite-direction candle before an engulfing break (2-candle rule), using the candle **body** as the zone:

- **Bullish OB** → previous candle is bearish (`close < open`) **and** the current candle **closes above** the previous candle's high → the previous candle's body is the bullish OB zone.
- **Bearish OB** → previous candle is bullish (`close > open`) **and** the current candle **closes below** the previous candle's low → the previous candle's body is the bearish OB zone.
- Zone (body only): **Top** = `max(open, close)`, **Bottom** = `min(open, close)`, **CE** = midpoint.

## How each FVG / OB is drawn

Both FVGs and OBs are drawn as **three horizontal lines** — **Top**, **CE** (midpoint), and **Bottom** — each with a text label at its right end (`+4H FVG Top`, `-D OB CE`, etc.):

```
+W FVG Top / CE / Bottom      -W FVG Top / CE / Bottom
+D FVG Top / CE / Bottom      -D FVG Top / CE / Bottom
+4H FVG Top / CE / Bottom     -4H FVG Top / CE / Bottom
+15M FVG Top / CE / Bottom    -15M FVG Top / CE / Bottom
```

- `+` = **bullish** FVG, `-` = **bearish** FVG
- Each timeframe/direction has its own configurable color (default **5% opacity / 95% transparent** so lines are subtle; the right-end label text stays fully opaque for readability)

Each line extends to the right until **its own level is mitigated**, then it is **discontinued** — frozen at the bar where price re-entered it. The Top, CE, and Bottom of a single FVG are mitigated independently.

**Mitigation only starts after confirmation** — the candles that *form* a zone can never mitigate it. Checking begins only once the **confirmation candle closes** (candle 3 for an FVG; the engulfing candle for an OB). This prevents, for example, a bullish OB from being instantly "mitigated" by the very bullish candle that engulfed it.

**Mitigation is directional** — a level only counts as mitigated when price **re-enters the zone from the side it was left open**, not when the original impulse move created/extended it:

- **Bullish FVG** (gap below price) → filled from **above** (price drops back down into it)
- **Bearish FVG** (gap above price) → filled from **below** (price rallies back up into it)

**Wick / Body mode** (setting: *Mitigation by*) chooses what counts as reaching a level:

- **Wick** — the candle wick reaches the level (`high` / `low`)
- **Body** — the candle body reaches it (`max(open, close)` / `min(open, close)`)

## Features

| Setting | Description |
|---|---|
| **Show FVGs / OBs per W / D / 4H / 15M** | Toggle FVGs and OBs independently for each of the four timeframes, each with its own timeframe input |
| **FVG line colors** | Eight color inputs — Bullish (+)/Bearish (-) for W, D, 4H, 15M |
| **OB line colors** | Eight separate color inputs — Bullish (+)/Bearish (-) for W, D, 4H, 15M — so OBs are visually distinct from FVGs |
| **Line width / Mitigation by (Wick/Body)** | Shared by FVGs and OBs |
| **Show/Hide Lines** | Per-category visibility — Top, CE, Bottom toggled independently for every timeframe × direction, separately for FVGs (**24 toggles**) and OBs (**24 toggles**) |
| **Max FVGs per set** | Trims oldest FVGs/OBs per store to keep the chart clean |
| **Extend lines (bars)** | How far right each active level projects |
| **Show text labels** | Toggle the right-end labels; configurable **text size** and **font** (Default / Monospace — Pine has no Arial; Default is its Arial-like sans-serif) |
| **Show mitigated line labels** | When off, a level's label text is removed once that level is mitigated (the frozen line stays). Active levels always keep their label. Default on |
| **Dashboard (color legend)** | Off by default. A horizontal on-chart table (default top-right when enabled) with **one column per enabled level** — row 1 the short label (`+4H FVG T`, `+4H FVG CE`, `-D OB B`, …), row 2 the color swatch. A level appears only if it's actually shown on the chart (its timeframe is on **and** that Top/CE/Bottom toggle is on), so disabled levels are omitted. Configurable position, text size, background and text color; can be toggled off |
| **Alerts** | Built-in `alertcondition` fires for new W / D / 4H / 15M FVGs **and** OBs |

Both FVGs and OBs share the same directional Wick/Body mitigation (a level freezes when price re-enters the zone from the open side).

## 15M confluence filter

To cut noise, **15M zones are only drawn when they sit inside a higher-timeframe zone**:

- A **15M FVG** is drawn only if it **overlaps an active, same-direction HTF zone** — where "HTF zone" means *any* Weekly / Daily / 4H **FVG or OB**.
- A **15M OB** follows the same rule — drawn only if it overlaps an active, same-direction W/D/4H FVG or OB.

Details:

- **Overlap** = price-range intersection (partial counts, not just full containment).
- **Direction must match** (a bullish 15M zone only qualifies against a bullish HTF zone).
- Only **active (unmitigated)** HTF zones count.
- The check runs **when the 15M zone forms**, against the HTF zones that exist at that moment (non-repainting; no retroactive reveal if an HTF zone appears later).
- Higher-timeframe (W/D/4H) FVGs and OBs are always drawn normally — the filter only gates 15M.

## Installation

1. Open TradingView → **Pine Editor** (bottom panel).
2. Paste in the contents of [`multi_tf_fvg.pine`](./multi_tf_fvg.pine).
3. Click **Add to chart**.
4. Adjust colors/timeframes via the indicator settings (⚙️).

## Notes

- Uses non-repainting `request.security` (`lookahead_off`), so gaps confirm only after the higher-timeframe candle closes — this avoids repainting and false signals.

## License

MIT
