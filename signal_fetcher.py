import logging
import json
import re
import asyncio
from datetime import datetime
from typing import Optional, Dict, List
import aiohttp
from bs4 import BeautifulSoup
import ssl

# =========================================================
# LOGGING
# =========================================================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

logger = logging.getLogger("Signal-Fetcher")

# =========================================================
# CONFIGURATION
# =========================================================
TELEGRAM_CHANNEL_1 = "https://t.me/s/txauusd2"
TELEGRAM_CHANNEL_2 = "https://t.me/s/BhadinTradingAcademy3680"
WEBHOOK_URL = "http://localhost:25345/webhook"
PROCESSED_SIGNALS_FILE = "processed_signal_ids.json"
POLL_INTERVAL = 60  # 1 minute
MAX_MESSAGES = 3

# =========================================================
# PROCESSED SIGNALS STORAGE
# =========================================================

def load_processed_ids() -> set:
    """Load previously processed signal texts (unique identifiers)."""
    try:
        with open(PROCESSED_SIGNALS_FILE, 'r') as f:
            data = json.load(f)
            return set(data.get("processed_signals", []))
    except FileNotFoundError:
        return set()


def save_processed_ids(processed: set):
    """Save processed signal texts."""
    try:
        with open(PROCESSED_SIGNALS_FILE, 'w') as f:
            json.dump({
                "processed_signals": list(processed),
                "last_updated": datetime.now().isoformat() + "Z",
                "count": len(processed)
            }, f, indent=2)
        logger.debug(f"Saved {len(processed)} processed signals")
    except Exception as e:
        logger.error(f"Error saving processed signals: {str(e)}")


# =========================================================
# TELEGRAM SCRAPER
# =========================================================

async def scrape_telegram_messages(channel_url: str, max_messages: int = 12) -> List[Dict]:
    """
    Scrape latest N messages from Telegram channel.
    """
    try:
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE
        
        connector = aiohttp.TCPConnector(ssl=ssl_context)
        async with aiohttp.ClientSession(connector=connector) as session:
            async with session.get(channel_url) as response:
                if response.status != 200:
                    logger.error(f"Failed to fetch Telegram ({channel_url}): {response.status}")
                    return []
                
                html = await response.text()
                soup = BeautifulSoup(html, 'html.parser')
                
                messages = []
                message_elements = soup.find_all('div', class_='tgme_widget_message')
                
                for msg_elem in message_elements[:max_messages]:
                    try:
                        text_elem = msg_elem.find('div', class_='tgme_widget_message_text')
                        message_text = text_elem.get_text(strip=True) if text_elem else ""
                        
                        link_elem = msg_elem.find('a', class_='tgme_widget_message_date')
                        message_id = link_elem.get('href', '').split('/')[-1] if link_elem else ""
                        
                        if message_id and message_text:
                            messages.append({
                                "id": message_id,
                                "text": message_text,
                                "scraped_at": datetime.now().isoformat() + "Z"
                            })
                    except Exception as e:
                        logger.error(f"Error parsing message: {str(e)}")
                        continue
                
                return messages
    
    except Exception as e:
        logger.error(f"Scraping error ({channel_url}): {str(e)}")
        return []


# =========================================================
# SIGNAL PARSER
# =========================================================

def parse_trading_signal(text: str) -> Optional[Dict]:
    """
    Parse trading signal text to extract symbol, action, entry, SL, and TP levels.
    Handles formats like:
    - XAUUSD BUY. 4286  TP 4290 TP 4293 TP 4296 TP 4300  SL 4276
    - XAUUSD SELL. 4335  TP 4332 TP 4329 TP 4326 TP 4322  SL 4345
    """
    try:
        text = text.strip()
        
        # Extract symbol (6 uppercase letters like XAUUSD)
        symbol_match = re.search(r'^([A-Z]{6})\s+', text)
        if not symbol_match:
            return None
        
        symbol = symbol_match.group(1)
        
        # Extract action (BUY or SELL)
        action_match = re.search(r'\b(Buy|Sell|BUY|SELL)\b', text, re.IGNORECASE)
        if not action_match:
            return None
        
        action = action_match.group(1).upper()
        
        # Extract entry price (first number after action)
        remaining_text = text[action_match.end():]
        entry_match = re.search(r'[\.\s]+(\d+(?:\.\d+)?)', remaining_text)
        if not entry_match:
            return None
        
        entry = float(entry_match.group(1))
        
        # Extract SL (Stop Loss)
        sl_match = re.search(r'SL\s+(\d+(?:\.\d+)?)', text, re.IGNORECASE)
        if not sl_match:
            return None
        
        sl = float(sl_match.group(1))
        
        # Extract TP levels (Take Profit)
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
        logger.error(f"Error parsing signal: {str(e)}")
        return None


# =========================================================
# WEBHOOK SENDER
# =========================================================

async def send_signal_to_webhook(signal: Dict) -> bool:
    """
    Send parsed signal to webhook bridge.
    """
    try:
        payload = {
            "symbol": signal["symbol"],
            "action": signal["action"],
            "entry": signal["entry"],
            "sl": signal["sl"],
            "tp_levels": signal["tp_levels"],
            "price": str(signal["entry"]),
            "time": datetime.now().isoformat() + "Z"
        }
        
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE
        
        connector = aiohttp.TCPConnector(ssl=ssl_context)
        async with aiohttp.ClientSession(connector=connector) as session:
            async with session.post(WEBHOOK_URL, json=payload) as response:
                if response.status in [200, 201]:
                    logger.info(f"✓ Signal sent: {signal['symbol']} {signal['action']} @ {signal['entry']}")
                    return True
                else:
                    logger.error(f"Webhook error: {response.status}")
                    return False
    
    except Exception as e:
        logger.error(f"Error sending webhook: {str(e)}")
        return False


# =========================================================
# MAIN LOOP
# =========================================================

async def fetch_and_process():
    """
    Main loop: fetch messages from both channels, check for new signals, and send them.
    """
    logger.info(f"Starting Signal Fetcher - monitoring 2 channels every {POLL_INTERVAL}s")
    logger.info(f"  Channel 1: {TELEGRAM_CHANNEL_1}")
    logger.info(f"  Channel 2: {TELEGRAM_CHANNEL_2}")
    
    processed_signals = load_processed_ids()
    logger.info(f"Loaded {len(processed_signals)} previously processed signals")
    
    while True:
        try:
            logger.info("Fetching latest messages from both channels...")
            
            # Fetch from both channels in parallel
            messages_1 = await scrape_telegram_messages(TELEGRAM_CHANNEL_1, MAX_MESSAGES)
            messages_2 = await scrape_telegram_messages(TELEGRAM_CHANNEL_2, MAX_MESSAGES)
            
            all_messages = messages_1 + messages_2
            logger.info(f"Fetched {len(messages_1)} from channel 1, {len(messages_2)} from channel 2")
            
            new_signals_count = 0
            
            for msg in all_messages:
                msg_id = msg.get("id")
                msg_text = msg.get("text")
                
                # Check if already processed (using signal text as unique identifier)
                if msg_text in processed_signals:
                    logger.debug(f"Skipping duplicate signal: {msg_text[:50]}...")
                    continue
                
                # Parse signal
                parsed = parse_trading_signal(msg_text)
                
                if parsed:
                    # Send to webhook
                    sent = await send_signal_to_webhook(parsed)
                    
                    if sent:
                        # Mark as processed (store the signal text)
                        processed_signals.add(msg_text)
                        save_processed_ids(processed_signals)
                        new_signals_count += 1
                        
                        logger.info(f"NEW SIGNAL: {parsed['symbol']} {parsed['action']}")
                        logger.info(f"  Entry: {parsed['entry']}")
                        logger.info(f"  SL:    {parsed['sl']}")
                        logger.info(f"  TP(s): {parsed['tp_levels']}")
                    else:
                        logger.warning(f"Failed to send signal for message ID {msg_id}")
                else:
                    logger.debug(f"Could not parse signal from message ID {msg_id}")
            
            if new_signals_count > 0:
                logger.info(f"Processed {new_signals_count} new signals")
            else:
                logger.debug("No new signals found")
            
            logger.info(f"Next check in {POLL_INTERVAL} seconds...")
            await asyncio.sleep(POLL_INTERVAL)
        
        except Exception as e:
            logger.error(f"Error in main loop: {str(e)}", exc_info=True)
            await asyncio.sleep(POLL_INTERVAL)


# =========================================================
# RUN
# =========================================================
if __name__ == "__main__":
    try:
        asyncio.run(fetch_and_process())
    except KeyboardInterrupt:
        logger.info("Signal Fetcher stopped by user")
    except Exception as e:
        logger.error(f"Fatal error: {str(e)}", exc_info=True)
