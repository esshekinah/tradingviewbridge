#!/bin/bash

################################################################################
# TradingView Webhook Bridge - Dokploy Deployment with Nginx Fix
#
# This script deploys the application to Dokploy and fixes Nginx configuration
# to properly handle POST requests on port 80
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
    print_header "Step 3: Configuring Nginx"
    
    print_info "Creating Nginx configuration..."
    
    # Create the Nginx config
    cat > $NGINX_CONFIG << 'NGINX_CONFIG_EOF'
# HTTP server (port 80)
server {
    listen 80;
    listen [::]:80;
    server_name ctrader.emmanuelshekinah.co.za;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Root location - catches ALL requests
    location / {
        proxy_pass http://localhost:25345;
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
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Webhook endpoint (POST)
    location /webhook {
        proxy_pass http://localhost:25345/webhook;
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
        proxy_pass http://localhost:25345/signal;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health endpoint (GET)
    location /health {
        proxy_pass http://localhost:25345/health;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# HTTPS server (port 443)
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

    location / {
        proxy_pass http://localhost:25345;
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
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /webhook {
        proxy_pass http://localhost:25345/webhook;
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

    location /signal {
        proxy_pass http://localhost:25345/signal;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://localhost:25345/health;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINX_CONFIG_EOF

    print_success "Nginx configuration created"
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
    print_header "Step 8: Testing Endpoints"
    
    print_info "Waiting for backend to be ready..."
    sleep 5
    
    print_info "Testing health endpoint..."
    if curl -s http://localhost:25345/health > /dev/null 2>&1; then
        print_success "Health endpoint responding"
    else
        print_warning "Health endpoint not responding (backend may still be starting)"
    fi
    
    print_info "Testing signal endpoint..."
    if curl -s http://localhost:25345/signal > /dev/null 2>&1; then
        print_success "Signal endpoint responding"
    else
        print_warning "Signal endpoint not responding"
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
    
    echo -e "${GREEN}✓ Nginx configured and running${NC}"
    echo -e "${GREEN}✓ Ready for application deployment${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Deploy application via Dokploy dashboard"
    echo "2. Test endpoints:"
    echo "   curl http://$DOMAIN/health"
    echo "   curl -X POST http://$DOMAIN/webhook -H 'Content-Type: application/json' -d '{\"symbol\":\"XAUUSD\",\"action\":\"SELL\",\"price\":\"3345.12\",\"time\":\"2026-05-27T10:00:00Z\"}'"
    echo "3. Configure cBot with:"
    echo "   Server: $DOMAIN"
    echo "   Port: 80"
    echo "   HTTPS: false"
    echo ""
}

# Run main function
main
