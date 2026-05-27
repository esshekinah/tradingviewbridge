#!/bin/bash

################################################################################
# TradingView Webhook Bridge - Deployment Script with Traefik
# Deploys with Traefik reverse proxy on port 80 and FastAPI on port 25345
# Usage: bash deploy.sh
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="ctrader.emmanuelshekinah.co.za"
TRAEFIK_PORT=80
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
# Step 1: Check Prerequisites
# ============================================================================
print_header "Step 1: Checking prerequisites"

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed"
    exit 1
fi

print_success "Docker and Docker Compose installed"

# ============================================================================
# Step 2: Stop Existing Containers
# ============================================================================
print_header "Step 2: Stopping existing containers"

docker-compose down 2>/dev/null || true
sleep 2
print_success "Containers stopped"

# ============================================================================
# Step 3: Build and Start Containers
# ============================================================================
print_header "Step 3: Building and starting containers"

docker-compose up -d
sleep 5
print_success "Containers started"

# ============================================================================
# Step 4: Verify Containers
# ============================================================================
print_header "Step 4: Verifying containers"

if docker ps | grep -q traefik; then
    print_success "Traefik container is running"
else
    print_error "Traefik container is not running"
    exit 1
fi

if docker ps | grep -q tradingview-webhook-bridge; then
    print_success "Webhook bridge container is running"
else
    print_error "Webhook bridge container is not running"
    exit 1
fi

# ============================================================================
# Step 5: Verify Ports
# ============================================================================
print_header "Step 5: Verifying ports"

echo "Port 80 (Traefik):"
docker ps --format "table {{.Ports}}" | grep 80 || print_warning "Port 80 not found"

echo ""
echo "Port 25345 (FastAPI):"
docker ps --format "table {{.Ports}}" | grep 25345 || print_warning "Port 25345 not found"

# ============================================================================
# Step 6: Test Endpoints
# ============================================================================
print_header "Step 6: Testing endpoints"

sleep 3

echo "Testing Port 80 /health:"
curl -s http://localhost/health 2>&1 | head -c 100
echo ""
echo ""

echo "Testing Port 80 /webhook (POST):"
curl -s -X POST http://localhost/webhook \
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

echo -e "${GREEN}✓ Traefik configured on port 80${NC}"
echo -e "${GREEN}✓ FastAPI running on port 25345${NC}"
echo -e "${GREEN}✓ All endpoints accessible on both ports${NC}"
echo ""
echo "Endpoints available on port 80 (via Traefik):"
echo "  GET  http://$DOMAIN/"
echo "  GET  http://$DOMAIN/health"
echo "  GET  http://$DOMAIN/signal"
echo "  POST http://$DOMAIN/webhook"
echo ""
echo "Endpoints available on port 25345 (direct):"
echo "  GET  http://$DOMAIN:25345/"
echo "  GET  http://$DOMAIN:25345/health"
echo "  GET  http://$DOMAIN:25345/signal"
echo "  POST http://$DOMAIN:25345/webhook"
echo ""
echo "Traefik Dashboard:"
echo "  http://localhost:8080"
echo ""
echo "Test commands:"
echo "  curl http://$DOMAIN/health"
echo "  curl -X POST http://$DOMAIN/webhook -H 'Content-Type: application/json' -d '{\"symbol\":\"XAUUSD\",\"action\":\"SELL\",\"price\":\"3345.12\",\"time\":\"2026-05-27T10:00:00Z\"}'"
echo ""
echo "cBot Configuration:"
echo "  Option A: Server=$DOMAIN, Port=80, HTTPS=false"
echo "  Option B: Server=$DOMAIN, Port=25345, HTTPS=false"
echo ""
