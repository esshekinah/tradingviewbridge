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


# =========================================================
# WEBHOOK RECEIVER (FIXED - RAW SAFE INPUT)
# =========================================================
@app.post("/webhook")
async def receive_webhook(request: Request):
    global latest_signal

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

        logger.info(f"STORED SIGNAL: {latest_signal}")

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
# GET SIGNAL (FIXED - NEVER RETURNS 404)
# =========================================================
@app.get("/signal")
async def get_signal():
    global latest_signal
    
    if latest_signal is None:
        logger.warning("No signal yet requested by client")

        return {
            "status": "no_signal",
            "message": "No TradingView signal received yet"
        }

    signal_data = latest_signal.copy()
    latest_signal = None  # Clear signal after retrieval
    logger.info(f"Signal retrieved and cleared: {signal_data}")
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