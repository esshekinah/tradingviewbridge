================================================================================
TradingView Webhook Bridge - Deployment Guide
================================================================================

QUICK START (2 minutes):

1. SSH into VPS:
   ssh root@ctrader.emmanuelshekinah.co.za

2. Run deployment script:
   cd /root
   bash deploy.sh

3. Test endpoints:
   
   Port 80:
   curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook \
     -H "Content-Type: application/json" \
     -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'
   
   Port 25345:
   curl -X POST http://ctrader.emmanuelshekinah.co.za:25345/webhook \
     -H "Content-Type: application/json" \
     -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'

4. Configure cBot:
   Server: ctrader.emmanuelshekinah.co.za
   Port: 80 (or 25345)
   HTTPS: false

================================================================================
FILES
================================================================================

Core Application:
  main.py                    - FastAPI webhook bridge
  requirements.txt           - Python dependencies
  Dockerfile                 - Docker image
  docker-compose.yml         - Docker compose config
  cTrader_WebhookBridge_cBot.cs - cTrader cBot code

Deployment:
  deploy.sh                  - Deployment script (RUN THIS)
  nginx.conf                 - Nginx configuration

Utilities:
  monitor.sh                 - Monitor application
  troubleshoot.sh            - Troubleshooting script
  setup-dokploy.sh           - Dokploy setup script

Documentation:
  README.txt                 - This file
  CBOT_FILES.txt             - cBot files list
  PACKAGE_CONTENTS.txt       - Package contents

================================================================================
ENDPOINTS
================================================================================

All endpoints work on both port 80 and port 25345:

GET /
  Returns API info
  Example: curl http://ctrader.emmanuelshekinah.co.za/

GET /health
  Returns health status
  Example: curl http://ctrader.emmanuelshekinah.co.za/health

GET /signal
  Returns latest stored signal
  Example: curl http://ctrader.emmanuelshekinah.co.za/signal

POST /webhook
  Receive TradingView alerts
  Example: curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook \
    -H "Content-Type: application/json" \
    -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'

================================================================================
DEPLOYMENT STEPS
================================================================================

1. SSH into VPS:
   ssh root@ctrader.emmanuelshekinah.co.za

2. Navigate to root directory:
   cd /root

3. Run deployment script:
   bash deploy.sh

   The script will:
   - Stop Nginx
   - Backup current configuration
   - Apply new Nginx configuration
   - Enable the site
   - Test configuration
   - Start Nginx
   - Verify both ports
   - Test all endpoints

4. Verify deployment:
   sudo systemctl status nginx
   sudo netstat -tlnp | grep -E ":80|:25345"

5. Test endpoints:
   curl http://ctrader.emmanuelshekinah.co.za/health
   curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook ...

6. Configure cBot with server and port

================================================================================
CBOT CONFIGURATION
================================================================================

Use either port in your cBot settings:

Option A (Port 80 via Nginx):
  Server IP/Domain: ctrader.emmanuelshekinah.co.za
  Server Port: 80
  Use HTTPS: false

Option B (Port 25345 Direct):
  Server IP/Domain: ctrader.emmanuelshekinah.co.za
  Server Port: 25345
  Use HTTPS: false

Both work identically!

================================================================================
TROUBLESHOOTING
================================================================================

Port 80 not working:
  1. Check Nginx is running: sudo systemctl status nginx
  2. Check ports: sudo netstat -tlnp | grep -E ":80|:25345"
  3. Check config: sudo nginx -t
  4. Check logs: tail -f /var/log/nginx/error.log
  5. Restart: sudo systemctl restart nginx

Port 25345 not responding:
  1. Check Docker: docker ps | grep tradingview
  2. Check port: sudo netstat -tlnp | grep 25345
  3. Test backend: curl http://localhost:25345/health

Nginx won't start:
  1. Check syntax: sudo nginx -t
  2. Check logs: sudo journalctl -u nginx -n 50
  3. Check port 80: sudo netstat -tlnp | grep :80

================================================================================
VERIFICATION CHECKLIST
================================================================================

[ ] Nginx is running: sudo systemctl status nginx
[ ] Port 80 is listening: sudo netstat -tlnp | grep :80
[ ] Port 25345 is listening: sudo netstat -tlnp | grep :25345
[ ] Nginx config is valid: sudo nginx -t
[ ] Port 80 /health works: curl http://localhost/health
[ ] Port 80 /webhook works: curl -X POST http://localhost/webhook ...
[ ] Port 25345 /health works: curl http://localhost:25345/health
[ ] Port 25345 /webhook works: curl -X POST http://localhost:25345/webhook ...
[ ] cBot configured and connected

================================================================================
TEST COMMANDS
================================================================================

Test Port 80:
  curl http://ctrader.emmanuelshekinah.co.za/health
  curl http://ctrader.emmanuelshekinah.co.za/signal
  curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook \
    -H "Content-Type: application/json" \
    -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'

Test Port 25345:
  curl http://ctrader.emmanuelshekinah.co.za:25345/health
  curl http://ctrader.emmanuelshekinah.co.za:25345/signal
  curl -X POST http://ctrader.emmanuelshekinah.co.za:25345/webhook \
    -H "Content-Type: application/json" \
    -d '{"symbol":"XAUUSD","action":"SELL","price":"3345.12","time":"2026-05-27T10:00:00Z"}'

================================================================================
SUMMARY
================================================================================

Files: 13 core files
Deployment: 1 script (deploy.sh)
Configuration: 1 file (nginx.conf)
Time to deploy: ~2 minutes
Complexity: Low (automated)

Ready to deploy? Run: bash deploy.sh

================================================================================
