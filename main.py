import logging
from datetime import datetime
from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="TradingView Webhook Bridge",
    description="Production-ready webhook receiver for TradingView alerts",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Data models
class TradingViewAlert(BaseModel):
    symbol: str
    action: str
    price: str
    time: str

class SignalResponse(BaseModel):
    symbol: str
    action: str
    price: str
    time: str
    received_at: str

# In-memory storage
latest_signal: Optional[SignalResponse] = None

@app.post("/webhook")
async def receive_webhook(alert: TradingViewAlert) -> dict:
    """
    Receive TradingView webhook alerts.
    
    Expected payload:
    {
        "symbol": "XAUUSD",
        "action": "BUY",
        "price": "3345.12",
        "time": "2026-05-27T10:00:00Z"
    }
    """
    global latest_signal
    
    try:
        # Store signal with reception timestamp
        latest_signal = SignalResponse(
            symbol=alert.symbol,
            action=alert.action,
            price=alert.price,
            time=alert.time,
            received_at=datetime.utcnow().isoformat() + "Z"
        )
        
        # Log the alert
        logger.info(
            f"Alert received - Symbol: {alert.symbol}, Action: {alert.action}, "
            f"Price: {alert.price}, Time: {alert.time}"
        )
        
        # Print to console
        print(f"\n{'='*60}")
        print(f"🔔 TRADINGVIEW ALERT RECEIVED")
        print(f"{'='*60}")
        print(f"Symbol:      {alert.symbol}")
        print(f"Action:      {alert.action}")
        print(f"Price:       {alert.price}")
        print(f"Time:        {alert.time}")
        print(f"Received at: {latest_signal.received_at}")
        print(f"{'='*60}\n")
        
        return {
            "status": "success",
            "message": "Alert received and stored",
            "symbol": alert.symbol,
            "action": alert.action
        }
    
    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error processing alert: {str(e)}")

@app.get("/signal")
async def get_latest_signal() -> dict:
    """
    Retrieve the latest stored signal.
    """
    if latest_signal is None:
        logger.warning("GET /signal called but no signal stored yet")
        raise HTTPException(status_code=404, detail="No signal received yet")
    
    logger.info(f"Latest signal retrieved - Symbol: {latest_signal.symbol}")
    return latest_signal.model_dump()

@app.get("/health")
async def health_check() -> dict:
    """
    Health check endpoint.
    """
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "signal_stored": latest_signal is not None
    }

@app.get("/")
async def root() -> dict:
    """
    Root endpoint with API information.
    """
    return {
        "service": "TradingView Webhook Bridge",
        "version": "1.0.0",
        "endpoints": {
            "POST /webhook": "Receive TradingView alerts",
            "GET /signal": "Get latest stored signal",
            "GET /health": "Health check",
            "GET /": "This endpoint"
        }
    }

if __name__ == "__main__":
    logger.info("Starting TradingView Webhook Bridge on 0.0.0.0:25345")
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=25345,
        log_level="info"
    )
