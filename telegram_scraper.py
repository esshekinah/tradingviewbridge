import logging
import json
import asyncio
from datetime import datetime
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

logger = logging.getLogger("Telegram-Scraper")

# =========================================================
# CONFIGURATION
# =========================================================
TELEGRAM_URL = "https://t.me/s/txauusd2"
POLL_INTERVAL = 60  # 1 minute
OUTPUT_FILE = "telegram_messages.json"

# =========================================================
# SCRAPER
# =========================================================

async def scrape_telegram_messages():
    """
    Scrape latest 10 messages from Telegram channel.
    """
    try:
        # Create SSL context that doesn't verify certificates
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE
        
        connector = aiohttp.TCPConnector(ssl=ssl_context)
        async with aiohttp.ClientSession(connector=connector) as session:
            async with session.get(TELEGRAM_URL) as response:
                if response.status != 200:
                    logger.error(f"Failed to fetch page: {response.status}")
                    return None
                
                html = await response.text()
                soup = BeautifulSoup(html, 'html.parser')
                
                messages = []
                
                # Find all message containers
                message_elements = soup.find_all('div', class_='tgme_widget_message')
                
                # Get latest 10 messages
                for msg_elem in message_elements[:10]:
                    try:
                        # Extract message text
                        text_elem = msg_elem.find('div', class_='tgme_widget_message_text')
                        message_text = text_elem.get_text(strip=True) if text_elem else ""
                        
                        # Extract timestamp
                        time_elem = msg_elem.find('a', class_='tgme_widget_message_date')
                        timestamp = time_elem.get_text(strip=True) if time_elem else ""
                        
                        # Extract message ID from link if available
                        link_elem = msg_elem.find('a', class_='tgme_widget_message_date')
                        message_id = link_elem.get('href', '').split('/')[-1] if link_elem else ""
                        
                        message_obj = {
                            "id": message_id,
                            "text": message_text,
                            "timestamp": timestamp,
                            "scraped_at": datetime.utcnow().isoformat() + "Z"
                        }
                        
                        messages.append(message_obj)
                        logger.info(f"Extracted message: {message_id} - {message_text[:50]}...")
                    
                    except Exception as e:
                        logger.error(f"Error parsing message element: {str(e)}")
                        continue
                
                return messages
    
    except Exception as e:
        logger.error(f"Scraping error: {str(e)}", exc_info=True)
        return None


async def save_messages_to_json(messages):
    """
    Save messages to JSON file.
    """
    try:
        data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "total_messages": len(messages) if messages else 0,
            "messages": messages if messages else [],
            "url": TELEGRAM_URL
        }
        
        with open(OUTPUT_FILE, 'w') as f:
            json.dump(data, f, indent=2)
        
        logger.info(f"Saved {len(messages) if messages else 0} messages to {OUTPUT_FILE}")
        return data
    
    except Exception as e:
        logger.error(f"Error saving to JSON: {str(e)}", exc_info=True)
        return None


async def poll_loop():
    """
    Main polling loop - runs every 1 minute.
    """
    logger.info(f"Starting Telegram scraper - polling every {POLL_INTERVAL} seconds")
    
    while True:
        logger.info("Fetching latest messages from Telegram...")
        messages = await scrape_telegram_messages()
        
        if messages:
            await save_messages_to_json(messages)
            logger.info(f"Successfully extracted {len(messages)} messages")
        else:
            logger.warning("No messages extracted")
        
        logger.info(f"Next poll in {POLL_INTERVAL} seconds...")
        await asyncio.sleep(POLL_INTERVAL)


# =========================================================
# RUN
# =========================================================
if __name__ == "__main__":
    try:
        asyncio.run(poll_loop())
    except KeyboardInterrupt:
        logger.info("Scraper stopped by user")
    except Exception as e:
        logger.error(f"Fatal error: {str(e)}", exc_info=True)
