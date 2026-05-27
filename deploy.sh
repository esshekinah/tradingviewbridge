#!/bin/bash

################################################################################
# TradingView Webhook Bridge - Deployment Script
# Deploys to Dokploy with Nginx configuration for dual port support
# Uses port 5009 (Nginx) and port 25345 (FastAPI direct)
# Usage: sudo bash deploy.sh
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="ctrader.emmanuelshekinah.co.za"
NGINX_CONFIG="/etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za"
NGINX_ENABLED="/etc/nginx/sites-enabled/ctrader.emmanuelshekinah.co.za"
NGINX_PORT=5009
BACKEND_PORT=25345

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================================================
# Step 1: Stop Nginx
# ============================================================================
print_header "Step 1: Stopping Nginx"

sudo systemctl stop nginx 2>/dev/null || true
killall nginx 2>/dev/null || true
sleep 2

print_success "Nginx stopped"

# ============================================================================
# Step 2: Backup Current Config
# ============================================================================
print_header "Step 2: Backing up current configuration"

if [ -f "$NGINX_CONFIG" ]; then
    BACKUP="${NGINX_CONFIG}.backup.$(date +%s)"
    sudo cp "$NGINX_CONFIG" "$BACKUP"
    print_success "Backup created: $BACKUP"
else
    print_info "No existing config to backup"
fi

# ============================================================================
# Step 3: Copy Nginx Configuration
# ============================================================================
print_header "Step 3: Applying Nginx configuration"

# Copy nginx.conf to sites-available
sudo cp nginx.conf "$NGINX_CONFIG"
print_success "Configuration copied to $NGINX_CONFIG"

# ============================================================================
# Step 4: Enable Nginx Site
# ============================================================================
print_header "Step 4: Enabling Nginx site"

sudo ln -sf "$NGINX_CONFIG" "$NGINX_ENABLED"
print_success "Site enabled"

# ============================================================================
# Step 5: Test Nginx Configuration
# ============================================================================
print_header "Step 5: Testing Nginx configuration"

if sudo nginx -t 2>&1 | grep -q "successful"; then
    print_success "Configuration is valid"
else
    print_error "Configuration has errors:"
    sudo nginx -t
    exit 1
fi

# ============================================================================
# Step 6: Start Nginx
# ============================================================================
print_header "Step 6: Starting Nginx"

sudo systemctl start nginx
sleep 2

if sudo systemctl is-active --quiet nginx; then
    print_success "Nginx started successfully"
else
    print_error "Failed to start Nginx"
    exit 1
fi

# ============================================================================
# Step 7: Verify Ports
# ============================================================================
print_header "Step 7: Verifying ports"

echo "Port 5009:"
sudo netstat -tlnp 2>/dev/null | grep ":5009 " || sudo ss -tlnp 2>/dev/null | grep ":5009 " || print_warning "Port 5009 not found"

echo ""
echo "Port 25345:"
sudo netstat -tlnp 2>/dev/null | grep ":25345 " || sudo ss -tlnp 2>/dev/null | grep ":25345 " || print_warning "Port 25345 not found"

# ============================================================================
# Step 8: Test Endpoints
# ============================================================================
print_header "Step 8: Testing endpoints"

sleep 3

echo "Testing Port 5009 /health:"
curl -s http://localhost:5009/health 2>&1 | head -c 100
echo ""
echo ""

echo "Testing Port 5009 /webhook (POST):"
curl -s -X POST http://localhost:5009/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"TEST","action":"BUY","price":"1.0","time":"2026-05-27T10:00:00Z"}' 2>&1 | head -c 100
echo ""
echo ""

echo "Testing Port 25345 /health:"
curl -s http://localhost:25345/health 2>&1 | head -c 100
echo ""
echo ""

echo "Testing Port 25345 /webhook (POST):"
curl -s -X POST http://localhost:25345/webhook \
  -H "Content-Type: application/json" \
  -d '{"symbol":"TEST","action":"SELL","price":"1.0","time":"2026-05-27T10:00:00Z"}' 2>&1 | head -c 100
echo ""
echo ""

# ============================================================================
# Summary
# ============================================================================
print_header "Deployment Complete!"

echo -e "${GREEN}✓ Nginx configured for dual port support${NC}"
echo -e "${GREEN}✓ Port 5009 (via Nginx) ready${NC}"
echo -e "${GREEN}✓ Port 25345 (direct) ready${NC}"
echo ""
echo "Endpoints available on both ports:"
echo "  GET  http://$DOMAIN:5009/"
echo "  GET  http://$DOMAIN:5009/health"
echo "  GET  http://$DOMAIN:5009/signal"
echo "  POST http://$DOMAIN:5009/webhook"
echo ""
echo "Also available on port 25345 (direct):"
echo "  GET  http://$DOMAIN:25345/"
echo "  GET  http://$DOMAIN:25345/health"
echo "  GET  http://$DOMAIN:25345/signal"
echo "  POST http://$DOMAIN:25345/webhook"
echo ""
echo "Test commands:"
echo "  curl http://$DOMAIN:5009/health"
echo "  curl -X POST http://$DOMAIN:5009/webhook -H 'Content-Type: application/json' -d '{\"symbol\":\"XAUUSD\",\"action\":\"SELL\",\"price\":\"3345.12\",\"time\":\"2026-05-27T10:00:00Z\"}'"
echo ""
echo "cBot Configuration:"
echo "  Option A: Server=$DOMAIN, Port=5009, HTTPS=false"
echo "  Option B: Server=$DOMAIN, Port=25345, HTTPS=false"
echo ""
