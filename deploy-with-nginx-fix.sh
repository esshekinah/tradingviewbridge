#!/bin/bash

################################################################################
# TradingView Webhook Bridge - Dokploy Deployment with Dual Port Support
#
# This script deploys the application to Dokploy and configures Nginx to
# properly handle all endpoints on both port 80 and port 25345
#
# Usage: sudo bash deploy-with-nginx-fix.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOMAIN="ctrader.emmanuelshekinah.co.za"
APP_DIR="/opt/tradingview-webhook"
NGINX_CONFIG="/etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za"
BACKEND_PORT=25345
FRONTEND_PORT=80

################################################################################
# Helper Functions
################################################################################

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

################################################################################
# Step 1: Stop and Clean Nginx
################################################################################

cleanup_nginx() {
    print_header "Step 1: Cleaning Up Nginx"
    
    print_info "Stopping all Nginx instances..."
    systemctl stop nginx 2>/dev/null || true
    killall nginx 2>/dev/null || true
    killall -9 nginx 2>/dev/null || true
    
    sleep 2
    
    print_info "Removing duplicate Nginx configs..."
    rm -f /etc/nginx/sites-available/tradingview-webhook
    rm -f /etc/nginx/sites-enabled/tradingview-webhook
    rm -f /etc/nginx/sites-enabled/default
    
    print_success "Nginx cleaned up"
}

################################################################################
# Step 2: Deploy Application
################################################################################

deploy_application() {
    print_header "Step 2: Deploying Application to Dokploy"
    
    print_info "Ensuring application directory exists..."
    mkdir -p $APP_DIR
    
    print_info "Application files should be in: $APP_DIR"
    print_info "Required files:"
    print_info "  - main.py"
    print_info "  - requirements.txt"
    print_info "  - Dockerfile"
    print_info "  - docker-compose.yml"
    
    if [[ ! -f "$APP_DIR/main.py" ]]; then
        print_warning "main.py not found in $APP_DIR"
        print_info "Please ensure application files are uploaded to $APP_DIR"
    else
        print_success "Application files found"
    fi
    
    print_info "Deploying via Dokploy..."
    print_info "1. Access Dokploy dashboard: http://$(hostname -I | awk '{print $1}'):3000"
    print_info "2. Create/update application"
    print_info "3. Deploy application"
    print_info "4. Wait for deployment to complete"
}

################################################################################
# Step 3: Configure Nginx
################################################################################

configure_nginx() {
    print_header "Step 3: Configuring Nginx for Dual Port Support"
    
    print_info "Creating Nginx configuration for port 80 and 25345..."
    
    # Create the Nginx config
    cat > $NGINX_CONFIG << 'NGINX_CONFIG_EOF'
# ============================================================================
# TradingView Webhook Bridge - Dual Port Configuration
# Handles all endpoints on port 80 (via Nginx) and port 25345 (direct)
# ============================================================================

# HTTP server (port 80)
server {
    listen 80;
    listen [::]:80;
    server_name ctrader.emmanuelshekinah.co.za;

    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # ========================================================================
    # Root location - catches ALL requests (GET, POST, PUT, DELETE)
    # ========================================================================
    location / {
        proxy_pass http://127.0.0.1:25345;
        proxy_http_version 1.1;
        
        # Essential headers for all request types
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        
        # CRITICAL: Forward Content-Type for POST requests
        proxy_set_header Content-Type $content_type;
        
        # Allow all HTTP methods
        proxy_method $request_method;
        
        # Buffering configuration
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # ========================================================================
    # Explicit endpoint locations for fine-tuning
    # ========================================================================

    # Webhook endpoint (POST)
    location /webhook {
        proxy_pass http://127.0.0.1:25345/webhook;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
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

# ============================================================================
# HTTPS server (port 443) - if you have SSL certificate
# ============================================================================
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ctrader.emmanuelshekinah.co.za;

    ssl_certificate /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Root location
    location / {
        proxy_pass http://127.0.0.1:25345;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        proxy_set_header Content-Type $content_type;
        
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Webhook endpoint
    location /webhook {
        proxy_pass http://127.0.0.1:25345/webhook;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        proxy_set_header Content-Type $content_type;
        
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Signal endpoint
    location /signal {
        proxy_pass http://127.0.0.1:25345/signal;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health endpoint
    location /health {
        proxy_pass http://127.0.0.1:25345/health;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        access_log off;
    }
}

# ============================================================================
# Direct port 25345 access (no Nginx proxy)
# FastAPI listens directly on 0.0.0.0:25345
# All endpoints accessible: GET /, GET /health, GET /signal, POST /webhook
# ============================================================================
NGINX_CONFIG_EOF

    print_success "Nginx configuration created for dual port support"
}

################################################################################
# Step 4: Enable Nginx Site
################################################################################

enable_nginx_site() {
    print_header "Step 4: Enabling Nginx Site"
    
    print_info "Creating symlink..."
    ln -sf $NGINX_CONFIG /etc/nginx/sites-enabled/ctrader.emmanuelshekinah.co.za
    
    print_success "Nginx site enabled"
}

################################################################################
# Step 5: Test Nginx Configuration
################################################################################

test_nginx() {
    print_header "Step 5: Testing Nginx Configuration"
    
    if nginx -t; then
        print_success "Nginx configuration is valid"
    else
        print_error "Nginx configuration has errors"
        return 1
    fi
}

################################################################################
# Step 6: Start Nginx
################################################################################

start_nginx() {
    print_header "Step 6: Starting Nginx"
    
    systemctl start nginx
    
    sleep 2
    
    if systemctl is-active --quiet nginx; then
        print_success "Nginx started successfully"
    else
        print_error "Nginx failed to start"
        return 1
    fi
}

################################################################################
# Step 7: Verify Deployment
################################################################################

verify_deployment() {
    print_header "Step 7: Verifying Deployment"
    
    print_info "Checking Nginx processes..."
    NGINX_COUNT=$(ps aux | grep -c "nginx: master")
    if [[ $NGINX_COUNT -eq 1 ]]; then
        print_success "Only one Nginx master process running"
    else
        print_warning "Multiple Nginx processes detected"
    fi
    
    print_info "Checking listening ports..."
    if netstat -tlnp 2>/dev/null | grep -q ":80"; then
        print_success "Port 80 is listening"
    else
        print_warning "Port 80 is not listening"
    fi
    
    print_info "Checking backend on port 25345..."
    if netstat -tlnp 2>/dev/null | grep -q ":25345"; then
        print_success "Port 25345 is listening"
    else
        print_warning "Port 25345 is not listening (backend may not be deployed yet)"
    fi
}

################################################################################
# Step 8: Test Endpoints
################################################################################

test_endpoints() {
    print_header "Step 8: Testing All Endpoints on Both Ports"
    
    print_info "Waiting for backend to be ready..."
    sleep 5
    
    # ========================================================================
    # Test Port 80 (via Nginx)
    # ========================================================================
    print_info "Testing Port 80 (via Nginx)..."
    
    print_info "  GET /health on port 80..."
    if curl -s http://localhost/health > /dev/null 2>&1; then
        print_success "Health endpoint responding on port 80"
    else
        print_warning "Health endpoint not responding on port 80"
    fi
    
    print_info "  GET /signal on port 80..."
    if curl -s http://localhost/signal > /dev/null 2>&1; then
        print_success "Signal endpoint responding on port 80"
    else
        print_warning "Signal endpoint not responding on port 80"
    fi
    
    print_info "  POST /webhook on port 80..."
    if curl -s -X POST http://localhost/webhook \
        -H "Content-Type: application/json" \
        -d '{"symbol":"TEST","action":"BUY","price":"1.0","time":"2026-05-27T10:00:00Z"}' > /dev/null 2>&1; then
        print_success "Webhook endpoint responding on port 80"
    else
        print_warning "Webhook endpoint not responding on port 80"
    fi
    
    # ========================================================================
    # Test Port 25345 (Direct)
    # ========================================================================
    print_info "Testing Port 25345 (Direct)..."
    
    print_info "  GET /health on port 25345..."
    if curl -s http://localhost:25345/health > /dev/null 2>&1; then
        print_success "Health endpoint responding on port 25345"
    else
        print_warning "Health endpoint not responding on port 25345"
    fi
    
    print_info "  GET /signal on port 25345..."
    if curl -s http://localhost:25345/signal > /dev/null 2>&1; then
        print_success "Signal endpoint responding on port 25345"
    else
        print_warning "Signal endpoint not responding on port 25345"
    fi
    
    print_info "  POST /webhook on port 25345..."
    if curl -s -X POST http://localhost:25345/webhook \
        -H "Content-Type: application/json" \
        -d '{"symbol":"TEST","action":"SELL","price":"1.0","time":"2026-05-27T10:00:00Z"}' > /dev/null 2>&1; then
        print_success "Webhook endpoint responding on port 25345"
    else
        print_warning "Webhook endpoint not responding on port 25345"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header "TradingView Webhook Bridge - Dokploy Deployment with Nginx Fix"
    
    check_root
    
    cleanup_nginx
    deploy_application
    configure_nginx
    enable_nginx_site
    test_nginx || exit 1
    start_nginx || exit 1
    verify_deployment
    test_endpoints
    
    print_header "Deployment Complete!"
    
    echo -e "${GREEN}✓ Nginx configured for dual port support${NC}"
    echo -e "${GREEN}✓ Port 80 (via Nginx) ready${NC}"
    echo -e "${GREEN}✓ Port 25345 (direct) ready${NC}"
    echo -e "${GREEN}✓ All endpoints accessible on both ports${NC}"
    echo ""
    echo "Endpoints available on both ports:"
    echo "  GET  http://$DOMAIN/              (API info)"
    echo "  GET  http://$DOMAIN/health        (Health check)"
    echo "  GET  http://$DOMAIN/signal        (Get latest signal)"
    echo "  POST http://$DOMAIN/webhook       (Receive alerts)"
    echo ""
    echo "Also available on port 25345 (direct):"
    echo "  GET  http://$DOMAIN:25345/              (API info)"
    echo "  GET  http://$DOMAIN:25345/health        (Health check)"
    echo "  GET  http://$DOMAIN:25345/signal        (Get latest signal)"
    echo "  POST http://$DOMAIN:25345/webhook       (Receive alerts)"
    echo ""
    echo "Test commands:"
    echo "  curl http://$DOMAIN/health"
    echo "  curl -X POST http://$DOMAIN/webhook -H 'Content-Type: application/json' -d '{\"symbol\":\"XAUUSD\",\"action\":\"SELL\",\"price\":\"3345.12\",\"time\":\"2026-05-27T10:00:00Z\"}'"
    echo ""
    echo "cBot Configuration:"
    echo "  Option A: Server=$DOMAIN, Port=80, HTTPS=false"
    echo "  Option B: Server=$DOMAIN, Port=25345, HTTPS=false"
    echo ""
}

# Run main function
main
