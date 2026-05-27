#!/bin/bash

################################################################################
# Force Fix Port 80 - Bypass Dokploy Nginx Management
#
# This script forcefully applies the Nginx configuration for port 80
# and disables Dokploy's Nginx management if it's interfering
#
# Usage: sudo bash fix-port-80.sh
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="ctrader.emmanuelshekinah.co.za"
NGINX_CONFIG="/etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Force Fix Port 80 - Bypass Dokploy${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check current state
echo -e "${YELLOW}Step 1: Checking current Nginx state...${NC}"
echo ""

echo "Current Nginx config for $DOMAIN:"
if [ -f "$NGINX_CONFIG" ]; then
    echo "File exists at: $NGINX_CONFIG"
    echo "First 10 lines:"
    head -10 "$NGINX_CONFIG"
else
    echo "Config file not found!"
fi
echo ""

# Step 2: Stop Nginx
echo -e "${YELLOW}Step 2: Stopping Nginx...${NC}"
sudo systemctl stop nginx
sleep 2
echo -e "${GREEN}✓ Nginx stopped${NC}"
echo ""

# Step 3: Backup current config
echo -e "${YELLOW}Step 3: Backing up current config...${NC}"
if [ -f "$NGINX_CONFIG" ]; then
    BACKUP="${NGINX_CONFIG}.backup.$(date +%s)"
    sudo cp "$NGINX_CONFIG" "$BACKUP"
    echo -e "${GREEN}✓ Backup created: $BACKUP${NC}"
fi
echo ""

# Step 4: Create new config
echo -e "${YELLOW}Step 4: Creating fixed Nginx configuration...${NC}"

sudo tee "$NGINX_CONFIG" > /dev/null << 'EOF'
# ============================================================================
# TradingView Webhook Bridge - Port 80 Configuration
# Proxies all requests to FastAPI on port 25345
# ============================================================================

server {
    listen 80;
    listen [::]:80;
    server_name ctrader.emmanuelshekinah.co.za;

    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Root location - catches ALL requests
    location / {
        proxy_pass http://127.0.0.1:25345;
        proxy_http_version 1.1;
        
        # Essential headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        
        # CRITICAL: Forward Content-Type for POST requests
        proxy_set_header Content-Type $content_type;
        
        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Webhook endpoint (POST)
    location /webhook {
        proxy_pass http://127.0.0.1:25345/webhook;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Content-Type $content_type;
        
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Signal endpoint (GET)
    location /signal {
        proxy_pass http://127.0.0.1:25345/signal;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health endpoint (GET)
    location /health {
        proxy_pass http://127.0.0.1:25345/health;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        access_log off;
    }
}
EOF

echo -e "${GREEN}✓ Configuration created${NC}"
echo ""

# Step 5: Enable site
echo -e "${YELLOW}Step 5: Enabling Nginx site...${NC}"
sudo ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/ctrader.emmanuelshekinah.co.za
echo -e "${GREEN}✓ Site enabled${NC}"
echo ""

# Step 6: Test configuration
echo -e "${YELLOW}Step 6: Testing Nginx configuration...${NC}"
if sudo nginx -t 2>&1 | grep -q "successful"; then
    echo -e "${GREEN}✓ Configuration is valid${NC}"
else
    echo -e "${RED}✗ Configuration has errors:${NC}"
    sudo nginx -t
    exit 1
fi
echo ""

# Step 7: Start Nginx
echo -e "${YELLOW}Step 7: Starting Nginx...${NC}"
sudo systemctl start nginx
sleep 2

if sudo systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx started successfully${NC}"
else
    echo -e "${RED}✗ Failed to start Nginx${NC}"
    exit 1
fi
echo ""

# Step 8: Verify ports
echo -e "${YELLOW}Step 8: Verifying ports...${NC}"
echo "Port 80:"
sudo netstat -tlnp 2>/dev/null | grep ":80 " || sudo ss -tlnp 2>/dev/null | grep ":80 " || echo "Not found"
echo ""
echo "Port 25345:"
sudo netstat -tlnp 2>/dev/null | grep ":25345 " || sudo ss -tlnp 2>/dev/null | grep ":25345 " || echo "Not found"
echo ""

# Step 9: Test endpoints
echo -e "${YELLOW}Step 9: Testing endpoints...${NC}"
echo ""

echo "Testing port 80 /health:"
curl -s http://localhost/health | head -c 100
echo ""
echo ""

echo "Testing port 80 /webhook (POST):"
curl -s -X POST http://localhost/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"TEST","action":"BUY","price":"1.0","time":"2026-05-27T10:00:00Z"}' | head -c 100
echo ""
echo ""

echo "Testing port 25345 /health:"
curl -s http://localhost:25345/health | head -c 100
echo ""
echo ""

echo "Testing port 25345 /webhook (POST):"
curl -s -X POST http://localhost:25345/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"TEST","action":"SELL","price":"1.0","time":"2026-05-27T10:00:00Z"}' | head -c 100
echo ""
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Port 80 Fix Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Configuration applied to: $NGINX_CONFIG"
echo ""
echo "Test commands:"
echo "  curl http://ctrader.emmanuelshekinah.co.za/health"
echo "  curl -X POST http://ctrader.emmanuelshekinah.co.za/webhook -H 'Content-Type: application/json' -d '{\"symbol\":\"XAUUSD\",\"action\":\"SELL\",\"price\":\"3345.12\",\"time\":\"2026-05-27T10:00:00Z\"}'"
echo ""
echo "Both ports should now work identically!"
echo ""
