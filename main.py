import logging
from datetime import datetime
from typing import Optional, Dict, Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# =========================================================
# LOGGING
# =========================================================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

logger = logging.getLogger("TV-Bridge")

# =========================================================
# APP SETUP
# =========================================================
app = FastAPI(
    title="TradingView Webhook Bridge",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# =========================================================
# MEMORY STORAGE
# =========================================================
latest_signal: Optional[Dict[str, Any]] = None
fetched_by: set = set()  # Track which broker IDs have fetched this signal


# =========================================================
# WEBHOOK RECEIVER (FIXED - RAW SAFE INPUT)
# =========================================================
@app.post("/webhook")
async def receive_webhook(request: Request):
    global latest_signal, fetched_by

    try:
        body = await request.json()

        logger.info(f"RAW WEBHOOK RECEIVED: {body}")

        # Validate required fields safely (NO Pydantic blocking)
        symbol = body.get("symbol")
        action = body.get("action")
        entry = body.get("entry")
        sl = body.get("sl")
        tp_levels = body.get("tp_levels", [])
        price = body.get("price")
        time = body.get("time")

        if not symbol or not action:
            logger.warning("Invalid webhook: missing symbol/action")
            return {
                "status": "error",
                "message": "Missing required fields: symbol/action"
            }

        # NEW SIGNAL: Reset fetched_by list
        fetched_by = set()

        latest_signal = {
            "status": "success",
            "symbol": symbol,
            "action": action,
            "entry": entry,
            "sl": sl,
            "tp_levels": tp_levels,
            "price": price,
            "time": time,
            "received_at": datetime.utcnow().isoformat() + "Z"
        }

        logger.info(f"✓ New signal stored: {symbol} {action} @ {entry}")
        logger.info(f"✓ Fetched_by list reset")

        return {
            "status": "success",
            "message": "signal stored",
            "symbol": symbol,
            "action": action
        }

    except Exception as e:
        logger.error(f"Webhook error: {str(e)}", exc_info=True)
        return {
            "status": "error",
            "message": f"Error processing alert: {str(e)}"
        }


# =========================================================
# GET SIGNAL (WITH BROKER ID TRACKING)
# =========================================================
@app.get("/signal")
async def get_signal(id: str = "default"):
    global latest_signal, fetched_by
    
    if latest_signal is None:
        logger.debug(f"[{id}] No signal available")
        return {
            "status": "no_signal",
            "message": "No TradingView signal received yet"
        }

    # Check if this broker already fetched this signal
    if id in fetched_by:
        logger.info(f"[{id}] Already fetched this signal")
        return {
            "status": "already_fetched",
            "message": f"Broker '{id}' has already fetched this signal",
            "fetched_by": list(fetched_by)
        }

    # First time this broker fetches: add to fetched_by and return signal
    fetched_by.add(id)
    signal_data = latest_signal.copy()
    
    logger.info(f"✓ [{id}] Signal delivered: {signal_data.get('symbol')} {signal_data.get('action')}")
    logger.info(f"  Fetched by: {list(fetched_by)}")
    
    return signal_data


# =========================================================
# HEALTH CHECK
# =========================================================
@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "signal_available": latest_signal is not None
    }


# =========================================================
# ROOT INFO
# =========================================================
@app.get("/")
async def root():
    return {
        "service": "TradingView Webhook Bridge",
        "status": "running",
        "endpoints": {
            "POST /webhook": "Send TradingView alerts here",
            "GET /signal": "Get latest signal",
            "GET /health": "Health check"
        }
    }


# =========================================================
# RUN SERVER
# =========================================================
if __name__ == "__main__":
    logger.info("Starting server on 0.0.0.0:25345")

    uvicorn.run(
        app,
        host="0.0.0.0",
        port=25345,
        log_level="info"
    )