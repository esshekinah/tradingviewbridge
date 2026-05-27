#!/bin/bash

################################################################################
# TradingView Webhook Bridge - Dokploy Setup Script
# 
# This script automates the deployment setup on Ubuntu with Dokploy
# Domain: ctrader.emmanuelshekinah.co.za
# Port: 25345
#
# Usage: sudo bash setup-dokploy.sh
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="ctrader.emmanuelshekinah.co.za"
EMAIL="your-email@example.com"  # Change this to your email
APP_DIR="/opt/tradingview-webhook"
LOG_DIR="/var/log/tradingview-webhook"
APP_PORT=25345
HTTP_PORT=80
HTTPS_PORT=443

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

check_command() {
    if ! command -v $1 &> /dev/null; then
        return 1
    fi
    return 0
}

################################################################################
# System Checks
################################################################################

check_system() {
    print_header "System Checks"
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot determine OS"
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        print_warning "This script is optimized for Ubuntu. Your OS: $ID"
    fi
    print_success "OS: $ID $VERSION_ID"
    
    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        print_error "No internet connectivity"
        exit 1
    fi
    print_success "Internet connectivity verified"
    
    # Check domain resolution
    if ! nslookup $DOMAIN &> /dev/null; then
        print_warning "Domain $DOMAIN does not resolve yet. Make sure DNS is configured."
    else
        print_success "Domain $DOMAIN resolves correctly"
    fi
}

################################################################################
# Update System
################################################################################

update_system() {
    print_header "Updating System Packages"
    
    apt-get update
    apt-get upgrade -y
    
    print_success "System packages updated"
}

################################################################################
# Install Docker
################################################################################

install_docker() {
    print_header "Installing Docker"
    
    if check_command docker; then
        print_success "Docker already installed: $(docker --version)"
        return
    fi
    
    # Install Docker
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    echo \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start Docker
    systemctl enable docker
    systemctl start docker
    
    print_success "Docker installed: $(docker --version)"
}

################################################################################
# Install Dokploy
################################################################################

install_dokploy() {
    print_header "Installing Dokploy"
    
    if check_command dokploy; then
        print_success "Dokploy already installed: $(dokploy --version)"
        return
    fi
    
    print_info "Installing Dokploy from official source..."
    curl -sSL https://dokploy.com/install.sh | sh
    
    # Enable and start Dokploy
    systemctl enable dokploy
    systemctl start dokploy
    
    print_success "Dokploy installed and started"
    print_info "Access Dokploy dashboard at: http://<your-vps-ip>:3000"
}

################################################################################
# Setup Application Directory
################################################################################

setup_app_directory() {
    print_header "Setting Up Application Directory"
    
    # Create directories
    mkdir -p $APP_DIR
    mkdir -p $LOG_DIR
    
    # Set permissions
    chown -R $SUDO_USER:$SUDO_USER $APP_DIR
    chown -R www-data:www-data $LOG_DIR
    chmod 755 $LOG_DIR
    
    print_success "Application directory: $APP_DIR"
    print_success "Log directory: $LOG_DIR"
}

################################################################################
# Configure Firewall
################################################################################

configure_firewall() {
    print_header "Configuring Firewall (UFW)"
    
    # Enable UFW
    ufw --force enable
    
    # Allow SSH (critical!)
    ufw allow 22/tcp
    print_success "SSH access allowed (port 22)"
    
    # Allow HTTP
    ufw allow 80/tcp
    print_success "HTTP allowed (port 80)"
    
    # Allow HTTPS
    ufw allow 443/tcp
    print_success "HTTPS allowed (port 443)"
    
    # Allow internal app port
    ufw allow 25345/tcp
    print_success "Application port allowed (port 25345)"
    
    # Show status
    print_info "Firewall status:"
    ufw status numbered
}

################################################################################
# Install Nginx
################################################################################

install_nginx() {
    print_header "Installing Nginx"
    
    if check_command nginx; then
        print_success "Nginx already installed: $(nginx -v 2>&1)"
        return
    fi
    
    apt-get install -y nginx
    
    # Enable Nginx
    systemctl enable nginx
    systemctl start nginx
    
    print_success "Nginx installed and started"
}

################################################################################
# Configure Nginx Reverse Proxy
################################################################################

configure_nginx() {
    print_header "Configuring Nginx Reverse Proxy"
    
    # Create certbot directory
    mkdir -p /var/www/certbot
    chown -R www-data:www-data /var/www/certbot
    
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/$DOMAIN << 'EOF'
# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ctrader.emmanuelshekinah.co.za;

    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all HTTP to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ctrader.emmanuelshekinah.co.za;

    # SSL certificates (will be created by Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ctrader.emmanuelshekinah.co.za/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Logging
    access_log /var/log/nginx/ctrader.access.log;
    error_log /var/log/nginx/ctrader.error.log;

    # Proxy settings
    client_max_body_size 10M;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Reverse proxy to FastAPI application
    location / {
        proxy_pass http://localhost:25345;
        proxy_http_version 1.1;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        
        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Health check endpoint (no logging)
    location /health {
        proxy_pass http://localhost:25345/health;
        access_log off;
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    if ! nginx -t; then
        print_error "Nginx configuration test failed"
        return 1
    fi
    
    # Reload Nginx
    systemctl reload nginx
    
    print_success "Nginx reverse proxy configured for $DOMAIN"
}

################################################################################
# Install Certbot
################################################################################

install_certbot() {
    print_header "Installing Certbot (Let's Encrypt)"
    
    if check_command certbot; then
        print_success "Certbot already installed: $(certbot --version)"
        return
    fi
    
    apt-get install -y certbot python3-certbot-nginx
    
    print_success "Certbot installed"
}

################################################################################
# Create SSL Certificate
################################################################################

create_ssl_certificate() {
    print_header "Creating SSL Certificate with Let's Encrypt"
    
    # Check if certificate already exists
    if [[ -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]]; then
        print_success "Certificate already exists for $DOMAIN"
        return
    fi
    
    print_info "Creating certificate for $DOMAIN..."
    print_warning "Make sure your domain is pointing to this server's IP address"
    
    certbot certonly --webroot \
        -w /var/www/certbot \
        -d $DOMAIN \
        --email $EMAIL \
        --agree-tos \
        --non-interactive \
        --preferred-challenges http
    
    if [[ $? -eq 0 ]]; then
        print_success "SSL certificate created successfully"
        
        # Reload Nginx with SSL
        systemctl reload nginx
        print_success "Nginx reloaded with SSL configuration"
    else
        print_error "Failed to create SSL certificate"
        print_info "Troubleshooting steps:"
        print_info "1. Verify domain DNS resolution: nslookup $DOMAIN"
        print_info "2. Check firewall allows port 80: sudo ufw status"
        print_info "3. Ensure Nginx is running: sudo systemctl status nginx"
        return 1
    fi
}

################################################################################
# Setup Auto-Renewal
################################################################################

setup_auto_renewal() {
    print_header "Setting Up Certificate Auto-Renewal"
    
    # Enable certbot timer
    systemctl enable certbot.timer
    systemctl start certbot.timer
    
    # Test renewal
    certbot renew --dry-run
    
    print_success "Certificate auto-renewal configured"
    print_info "Renewal will run automatically"
}

################################################################################
# Setup Log Rotation
################################################################################

setup_log_rotation() {
    print_header "Setting Up Log Rotation"
    
    cat > /etc/logrotate.d/tradingview-webhook << 'EOF'
/var/log/tradingview-webhook/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        systemctl reload dokploy > /dev/null 2>&1 || true
    endscript
}
EOF

    print_success "Log rotation configured"
}

################################################################################
# Verify Installation
################################################################################

verify_installation() {
    print_header "Verifying Installation"
    
    # Check Docker
    if check_command docker; then
        print_success "Docker: $(docker --version)"
    else
        print_error "Docker not found"
    fi
    
    # Check Dokploy
    if check_command dokploy; then
        print_success "Dokploy: $(dokploy --version)"
    else
        print_error "Dokploy not found"
    fi
    
    # Check Nginx
    if check_command nginx; then
        print_success "Nginx: $(nginx -v 2>&1)"
    else
        print_error "Nginx not found"
    fi
    
    # Check Certbot
    if check_command certbot; then
        print_success "Certbot: $(certbot --version)"
    else
        print_error "Certbot not found"
    fi
    
    # Check UFW
    if ufw status | grep -q "Status: active"; then
        print_success "UFW: Active"
    else
        print_warning "UFW: Not active"
    fi
    
    # Check directories
    if [[ -d $APP_DIR ]]; then
        print_success "Application directory: $APP_DIR"
    else
        print_error "Application directory not found"
    fi
    
    if [[ -d $LOG_DIR ]]; then
        print_success "Log directory: $LOG_DIR"
    else
        print_error "Log directory not found"
    fi
}

################################################################################
# Print Summary
################################################################################

print_summary() {
    print_header "Installation Summary"
    
    echo -e "${GREEN}Setup completed successfully!${NC}\n"
    
    echo "Configuration Details:"
    echo "  Domain: $DOMAIN"
    echo "  Application Port: $APP_PORT"
    echo "  HTTP Port: $HTTP_PORT"
    echo "  HTTPS Port: $HTTPS_PORT"
    echo "  App Directory: $APP_DIR"
    echo "  Log Directory: $LOG_DIR"
    echo ""
    
    echo "Next Steps:"
    echo "  1. Copy application files to: $APP_DIR"
    echo "  2. Access Dokploy dashboard: http://<your-vps-ip>:3000"
    echo "  3. Create new project and application in Dokploy"
    echo "  4. Deploy application using Docker"
    echo "  5. Access application: https://$DOMAIN"
    echo ""
    
    echo "Useful Commands:"
    echo "  View Dokploy logs: sudo journalctl -u dokploy -f"
    echo "  View Nginx logs: tail -f /var/log/nginx/ctrader.access.log"
    echo "  Check certificate: sudo certbot certificates"
    echo "  Renew certificate: sudo certbot renew --dry-run"
    echo "  Check firewall: sudo ufw status"
    echo ""
    
    echo "Documentation:"
    echo "  Dokploy: https://dokploy.com/docs"
    echo "  Nginx: https://nginx.org/en/docs/"
    echo "  Let's Encrypt: https://letsencrypt.org/"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    print_header "TradingView Webhook Bridge - Dokploy Setup"
    
    check_root
    check_system
    update_system
    install_docker
    install_dokploy
    setup_app_directory
    configure_firewall
    install_nginx
    configure_nginx
    install_certbot
    create_ssl_certificate
    setup_auto_renewal
    setup_log_rotation
    verify_installation
    print_summary
}

# Run main function
main
