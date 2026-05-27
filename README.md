# TradingView Webhook Bridge

A production-ready FastAPI webhook receiver for TradingView alerts. Listens on port 25345 and stores the latest signal in memory.

## Features

- ✅ FastAPI-based webhook receiver
- ✅ Listens on `0.0.0.0:25345`
- ✅ POST `/webhook` endpoint for receiving alerts
- ✅ GET `/signal` endpoint for retrieving latest signal
- ✅ GET `/health` endpoint for health checks
- ✅ CORS support enabled
- ✅ Comprehensive logging
- ✅ Error handling
- ✅ Docker & Docker Compose support
- ✅ Production-ready configuration

## Project Structure

```
.
├── main.py                 # FastAPI application
├── requirements.txt        # Python dependencies
├── Dockerfile             # Docker image definition
├── docker-compose.yml     # Docker Compose configuration
└── README.md              # This file
```

## Local Development

### Prerequisites

- Python 3.11+
- pip

### Installation

1. Clone or navigate to the project directory:
```bash
cd tradingview-webhook-bridge
```

2. Create a virtual environment (recommended):
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

### Running Locally

Start the server:
```bash
python main.py
```

The server will start on `http://0.0.0.0:25345`

### Testing Locally

In another terminal, test the endpoints:

**Send a test alert:**
```bash
curl -X POST http://localhost:25345/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "XAUUSD",
    "action": "BUY",
    "price": "3345.12",
    "time": "2026-05-27T10:00:00Z"
  }'
```

**Retrieve the latest signal:**
```bash
curl http://localhost:25345/signal
```

**Health check:**
```bash
curl http://localhost:25345/health
```

**API info:**
```bash
curl http://localhost:25345/
```

## Docker Deployment

### Prerequisites

- Docker
- Docker Compose

### Build and Run with Docker Compose

1. Build and start the container:
```bash
docker-compose up -d
```

2. View logs:
```bash
docker-compose logs -f tradingview-webhook
```

3. Stop the container:
```bash
docker-compose down
```

### Build and Run with Docker (Manual)

1. Build the image:
```bash
docker build -t tradingview-webhook-bridge .
```

2. Run the container:
```bash
docker run -d \
  --name tradingview-webhook \
  -p 25345:25345 \
  --restart unless-stopped \
  tradingview-webhook-bridge
```

3. View logs:
```bash
docker logs -f tradingview-webhook
```

4. Stop the container:
```bash
docker stop tradingview-webhook
docker rm tradingview-webhook
```

## Ubuntu Deployment (Production)

### Prerequisites

- Ubuntu 20.04 LTS or later
- Docker and Docker Compose installed
- Port 25345 accessible

### Deployment Steps

1. Clone the repository:
```bash
git clone <repository-url>
cd tradingview-webhook-bridge
```

2. Deploy with Docker Compose:
```bash
docker-compose up -d
```

3. Verify the service is running:
```bash
docker-compose ps
curl http://localhost:25345/health
```

4. View logs:
```bash
docker-compose logs -f
```

### Systemd Service (Optional)

Create `/etc/systemd/system/tradingview-webhook.service`:

```ini
[Unit]
Description=TradingView Webhook Bridge
After=docker.service
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=/path/to/tradingview-webhook-bridge
ExecStart=/usr/bin/docker-compose up
ExecStop=/usr/bin/docker-compose down
Restart=unless-stopped
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable tradingview-webhook
sudo systemctl start tradingview-webhook
```

## API Endpoints

### POST /webhook

Receive TradingView webhook alerts.

**Request:**
```json
{
  "symbol": "XAUUSD",
  "action": "BUY",
  "price": "3345.12",
  "time": "2026-05-27T10:00:00Z"
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Alert received and stored",
  "symbol": "XAUUSD",
  "action": "BUY"
}
```

### GET /signal

Retrieve the latest stored signal.

**Response:**
```json
{
  "symbol": "XAUUSD",
  "action": "BUY",
  "price": "3345.12",
  "time": "2026-05-27T10:00:00Z",
  "received_at": "2026-05-27T10:00:05.123456Z"
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-05-27T10:00:05.123456Z",
  "signal_stored": true
}
```

### GET /

API information endpoint.

## TradingView Configuration

In TradingView, configure your alert webhook URL as:

```
http://<your-server-ip>:25345/webhook
```

Example for local testing:
```
http://localhost:25345/webhook
```

## Logging

Logs are printed to console and include:
- Alert reception with full details
- Errors with stack traces
- Health check requests
- Signal retrievals

Example log output:
```
2026-05-27 10:00:05,123 - __main__ - INFO - Alert received - Symbol: XAUUSD, Action: BUY, Price: 3345.12, Time: 2026-05-27T10:00:00Z
```

## Error Handling

The application handles:
- Invalid JSON payloads
- Missing required fields
- No signal stored yet (404 on GET /signal)
- Server errors (500 with error details)

## Performance Notes

- In-memory storage: Latest signal is stored in memory (lost on restart)
- For persistent storage, consider adding a database
- Handles concurrent requests efficiently with async/await
- Suitable for high-frequency alert scenarios

## Security Considerations

- CORS is enabled for all origins (configure as needed)
- No authentication required (add if needed for production)
- Validate TradingView webhook source in production
- Use HTTPS in production (add reverse proxy like Nginx)

## Troubleshooting

**Port already in use:**
```bash
# Find process using port 25345
lsof -i :25345
# Kill the process
kill -9 <PID>
```

**Docker container won't start:**
```bash
docker-compose logs tradingview-webhook
```

**Connection refused:**
- Ensure firewall allows port 25345
- Check if service is running: `docker-compose ps`

## License

MIT
