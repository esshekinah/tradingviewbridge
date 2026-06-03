import logging
import json
import re
from datetime import datetime
from typing import Optional, Dict, List

# =========================================================
# LOGGING
# =========================================================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

logger = logging.getLogger("Signal-Analyzer")

# =========================================================
# CONFIGURATION
# =========================================================
INPUT_FILE = "telegram_messages.json"
OUTPUT_FILE = "analyzed_signals.json"
PROCESSED_SIGNALS_FILE = "processed_signals.json"

# =========================================================
# PROCESSED SIGNALS STORAGE
# =========================================================

def load_processed_signals() -> set:
    """Load previously processed signal IDs to avoid duplicates."""
    try:
        with open(PROCESSED_SIGNALS_FILE, 'r') as f:
            data = json.load(f)
            return set(data.get("processed_ids", []))
    except FileNotFoundError:
        return set()


def save_processed_signals(processed: set):
    """Save processed signal IDs."""
    try:
        with open(PROCESSED_SIGNALS_FILE, 'w') as f:
            json.dump({
                "processed_ids": list(processed),
                "last_updated": datetime.utcnow().isoformat() + "Z"
            }, f, indent=2)
    except Exception as e:
        logger.error(f"Error saving processed signals: {str(e)}")


# =========================================================
# SIGNAL PARSER
# =========================================================

def parse_trading_signal(text: str) -> Optional[Dict]:
    """
    Parse trading signal text to extract symbol, action, entry, and SL.
    
    Expected format: "XAUUSD Buy 4518   TP  4522 TP  4528 TP  4538 SL  4499"
    """
    try:
        # Clean up text
        text = text.strip()
        
        # Extract symbol (e.g., XAUUSD, EURUSD, etc.)
        symbol_match = re.search(r'^([A-Z]{6})\s+', text)
        if not symbol_match:
            logger.warning(f"Could not extract symbol from: {text}")
            return None
        
        symbol = symbol_match.group(1)
        
        # Extract action (BUY or SELL)
        action_match = re.search(r'\b(Buy|Sell|BUY|SELL)\b', text, re.IGNORECASE)
        if not action_match:
            logger.warning(f"Could not extract action from: {text}")
            return None
        
        action = action_match.group(1).upper()
        
        # Extract entry price (number after action)
        remaining_text = text[action_match.end():]
        entry_match = re.search(r'(\d+(?:\.\d+)?)', remaining_text)
        if not entry_match:
            logger.warning(f"Could not extract entry price from: {text}")
            return None
        
        entry = float(entry_match.group(1))
        
        # Extract SL (Stop Loss) - look for "SL" followed by a price
        sl_match = re.search(r'SL\s+(\d+(?:\.\d+)?)', text, re.IGNORECASE)
        if not sl_match:
            logger.warning(f"Could not extract SL from: {text}")
            return None
        
        sl = float(sl_match.group(1))
        
        # Extract all TP (Take Profit) levels
        tp_matches = re.findall(r'TP\s+(\d+(?:\.\d+)?)', text, re.IGNORECASE)
        tp_levels = [float(tp) for tp in tp_matches] if tp_matches else []
        
        return {
            "symbol": symbol,
            "action": action,
            "entry": entry,
            "sl": sl,
            "tp_levels": tp_levels,
            "raw_text": text
        }
    
    except Exception as e:
        logger.error(f"Error parsing signal '{text}': {str(e)}")
        return None


# =========================================================
# MAIN ANALYSIS
# =========================================================

def analyze_signals():
    """
    Analyze trading signals from telegram_messages.json and extract relevant data.
    """
    try:
        # Load input file
        with open(INPUT_FILE, 'r') as f:
            data = json.load(f)
        
        messages = data.get("messages", [])
        logger.info(f"Loaded {len(messages)} messages from {INPUT_FILE}")
        
        # Load previously processed signals
        processed_ids = load_processed_signals()
        logger.info(f"Found {len(processed_ids)} previously processed signals")
        
        # Analyze each message
        analyzed_signals = []
        new_signals = []
        
        for msg in messages:
            msg_id = msg.get("id")
            msg_text = msg.get("text")
            msg_timestamp = msg.get("scraped_at")
            
            # Skip if already processed
            if msg_id in processed_ids:
                logger.debug(f"Skipping duplicate signal (ID: {msg_id})")
                continue
            
            # Parse the signal
            parsed = parse_trading_signal(msg_text)
            
            if parsed:
                signal_obj = {
                    "message_id": msg_id,
                    "timestamp": msg.get("timestamp"),
                    "scraped_at": msg_timestamp,
                    "symbol": parsed["symbol"],
                    "action": parsed["action"],
                    "entry": parsed["entry"],
                    "sl": parsed["sl"],
                    "tp_levels": parsed["tp_levels"],
                    "risk_reward": calculate_risk_reward(parsed["action"], parsed["entry"], parsed["sl"], parsed["tp_levels"]),
                    "raw_text": parsed["raw_text"]
                }
                
                analyzed_signals.append(signal_obj)
                new_signals.append(signal_obj)
                processed_ids.add(msg_id)
                
                logger.info(f"✓ Parsed signal: {parsed['symbol']} {parsed['action']} @ {parsed['entry']} | SL: {parsed['sl']}")
            else:
                logger.warning(f"Failed to parse signal (ID: {msg_id}): {msg_text}")
        
        # Save analyzed signals
        output_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "total_analyzed": len(analyzed_signals),
            "new_signals": len(new_signals),
            "signals": analyzed_signals
        }
        
        with open(OUTPUT_FILE, 'w') as f:
            json.dump(output_data, f, indent=2)
        
        logger.info(f"Saved {len(analyzed_signals)} analyzed signals to {OUTPUT_FILE}")
        
        # Update processed signals
        save_processed_signals(processed_ids)
        logger.info(f"Marked {len(new_signals)} new signals as processed")
        
        return new_signals
    
    except FileNotFoundError:
        logger.error(f"Input file not found: {INPUT_FILE}")
        return []
    except Exception as e:
        logger.error(f"Error analyzing signals: {str(e)}", exc_info=True)
        return []


def calculate_risk_reward(action: str, entry: float, sl: float, tp_levels: List[float]) -> Optional[Dict]:
    """
    Calculate risk/reward ratio for the signal.
    """
    try:
        if action == "BUY":
            risk = entry - sl  # How much we lose if SL is hit
            if not tp_levels or risk <= 0:
                return None
            
            # Use first TP as primary target
            reward = tp_levels[0] - entry
            
            if reward <= 0:
                return None
            
            return {
                "risk": round(risk, 2),
                "reward": round(reward, 2),
                "ratio": round(reward / risk, 2)
            }
        
        elif action == "SELL":
            risk = sl - entry  # How much we lose if SL is hit
            if not tp_levels or risk <= 0:
                return None
            
            # Use first TP as primary target
            reward = entry - tp_levels[0]
            
            if reward <= 0:
                return None
            
            return {
                "risk": round(risk, 2),
                "reward": round(reward, 2),
                "ratio": round(reward / risk, 2)
            }
    
    except Exception as e:
        logger.error(f"Error calculating risk/reward: {str(e)}")
        return None


# =========================================================
# RUN
# =========================================================
if __name__ == "__main__":
    logger.info("Starting Signal Analyzer...")
    new_signals = analyze_signals()
    
    if new_signals:
        logger.info(f"\n{'='*60}")
        logger.info(f"NEW SIGNALS FOUND: {len(new_signals)}")
        logger.info(f"{'='*60}")
        for sig in new_signals:
            logger.info(f"\n{sig['symbol']} {sig['action']}")
            logger.info(f"  Entry:  {sig['entry']}")
            logger.info(f"  SL:     {sig['sl']}")
            logger.info(f"  TP(s):  {sig['tp_levels']}")
            if sig['risk_reward']:
                logger.info(f"  R/R:    {sig['risk_reward']['ratio']} ({sig['risk_reward']['risk']} risk / {sig['risk_reward']['reward']} reward)")
    else:
        logger.info("No new signals found or all signals were duplicates")
