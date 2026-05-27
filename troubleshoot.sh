#!/bin/bash

################################################################################
# TradingView Webhook Bridge - Troubleshooting Script
#
# This script helps diagnose and fix common deployment issues
#
# Usage: sudo bash troubleshoot.sh
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
APP_PORT=25345
CONTAINER_NAME="tradingview-webhook-bridge"

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
# System Diagnostics
################################################################################

check_system() {
    print_header "System Diagnostics"
    
    # Check OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        print_info "OS: $ID $VERSION_ID"
    fi
    
    # Check disk space
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    print_info "Disk Usage: $DISK_USAGE"
    
    if [[ ${DISK_USAGE%\%} -gt 90 ]]; then
        print_error "Disk usage is critical (>90%)"
    elif [[ ${DISK_USAGE%\%} -gt 80 ]]; then
        print_warning "Disk usage is high (>80%)"
    else
        print_success "Disk usage is normal"
    fi
    
    # Check memory
    MEM_USAGE=$(free | awk 'NR==2 {printf("%.0f%%", $3/$2 * 100)}')
    print_info "Memory Usage: $MEM_USAGE"
    
    # Check uptime
    UPTIME=$(uptime -p)
    print_info "Uptime: $UPTIME"
}

################################################################################
# Docker Diagnostics
################################################################################

check_docker() {
    print_header "Docker Diagnostics"
    
    # Check Docker daemon
    if ! systemctl is-active --quiet docker; then
        print_error "Docker daemon is not running"
        print_info "Starting Docker..."
        systemctl start docker
        print_success "Docker started"
    else
        print_success "Docker daemon is running"
    fi
    
    # Check Docker version
    DOCKER_VERSION=$(docker --version)
    print_info "Docker: $DOCKER_VERSION"
    
    # Check container status
    if docker ps -a --format '{{.Names}}' | grep -q $CONTAINER_NAME; then
        if docker ps --format '{{.Names}}' | grep -q $CONTAINER_NAME; then
            print_success "Container is running: $CONTAINER_NAME"
            
            # Get container stats
            CONTAINER_ID=$(docker ps --format '{{.ID}}' --filter "name=$CONTAINER_NAME")
            STATS=$(docker stats --no-stream $CONTAINER_ID --format "CPU: {{.CPUPerc}} | Memory: {{.MemUsage}}")
            print_info "Container Stats: $STATS"
        else
            print_error "Container exists but is not running: $CONTAINER_NAME"
            print_info "Attempting to start container..."
            docker start $CONTAINER_NAME
            print_success "Container started"
        fi
    else
        print_error "Container not found: $CONTAINER_NAME"
    fi
    
    # Check Docker images
    if docker images --format '{{.Repository}}' | grep -q tradingview; then
        print_success "Docker image found"
    else
        print_warning "Docker image not found"
    fi
}

################################################################################
# Application Diagnostics
################################################################################

check_application() {
    print_header "Application Diagnostics"
    
    # Check if port is listening
    if netstat -tlnp 2>/dev/null | grep -q ":$APP_PORT"; then
        print_success "Application is listening on port $APP_PORT"
    else
        print_error "Application is not listening on port $APP_PORT"
    fi
    
    # Check health endpoint (local)
    print_info "Testing health endpoint (local)..."
    if curl -s http://localhost:$APP_PORT/health > /dev/null 2>&1; then
        HEALTH=$(curl -s http://localhost:$APP_PORT/health)
        print_success "Health endpoint responding"
        print_info "Response: $HEALTH"
    else
        print_error "Health endpoint not responding"
    fi
    
    # Check application logs
    print_info "Recent application logs:"
    docker logs --tail 20 $CONTAINER_NAME 2>/dev/null || print_warning "Could not retrieve logs"
}

################################################################################
# Nginx Diagnostics
################################################################################

check_nginx() {
    print_header "Nginx Diagnostics"
    
    # Check if Nginx is running
    if systemctl is-active --quiet nginx; then
        print_success "Nginx is running"
    else
        print_error "Nginx is not running"
        print_info "Starting Nginx..."
        systemctl start nginx
        print_success "Nginx started"
    fi
    
    # Check Nginx configuration
    if nginx -t 2>&1 | grep -q "successful"; then
        print_success "Nginx configuration is valid"
    else
        print_error "Nginx configuration has errors"
        nginx -t
    fi
    
    # Check if site is enabled
    if [[ -L /etc/nginx/sites-enabled/$DOMAIN ]]; then
        print_success "Site is enabled: $DOMAIN"
    else
        print_warning "Site is not enabled: $DOMAIN"
    fi
    
    # Check listening ports
    print_info "Nginx listening ports:"
    netstat -tlnp 2>/dev/null | grep nginx || print_warning "Could not determine listening ports"
}

################################################################################
# SSL/HTTPS Diagnostics
################################################################################

check_ssl() {
    print_header "SSL/HTTPS Diagnostics"
    
    # Check certificate
    CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    
    if [[ -f $CERT_PATH ]]; then
        print_success "Certificate found: $CERT_PATH"
        
        # Check expiry
        EXPIRY=$(openssl x509 -in $CERT_PATH -noout -enddate | cut -d= -f2)
        print_info "Certificate expiry: $EXPIRY"
        
        # Check days until expiry
        DAYS_LEFT=$(openssl x509 -in $CERT_PATH -noout -dates | grep notAfter | cut -d= -f2 | xargs -I {} date -d {} +%s | xargs -I {} echo "($({} - $(date +%s)) / 86400)" | bc)
        
        if [[ $DAYS_LEFT -lt 0 ]]; then
            print_error "Certificate has expired"
        elif [[ $DAYS_LEFT -lt 30 ]]; then
            print_warning "Certificate expires in $DAYS_LEFT days"
        else
            print_success "Certificate is valid for $DAYS_LEFT days"
        fi
    else
        print_error "Certificate not found: $CERT_PATH"
    fi
    
    # Check Certbot
    if command -v certbot &> /dev/null; then
        print_success "Certbot is installed"
        
        # Check renewal timer
        if systemctl is-enabled certbot.timer &> /dev/null; then
            print_success "Certbot renewal timer is enabled"
        else
            print_warning "Certbot renewal timer is not enabled"
        fi
    else
        print_error "Certbot is not installed"
    fi
}

################################################################################
# Network Diagnostics
################################################################################

check_network() {
    print_header "Network Diagnostics"
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Internet connectivity is working"
    else
        print_error "No internet connectivity"
    fi
    
    # Check DNS resolution
    if nslookup $DOMAIN &> /dev/null; then
        IP=$(nslookup $DOMAIN | grep "Address:" | tail -1 | awk '{print $2}')
        print_success "Domain resolves to: $IP"
    else
        print_error "Domain does not resolve: $DOMAIN"
    fi
    
    # Check HTTPS access
    print_info "Testing HTTPS access..."
    if curl -s -I https://$DOMAIN/health > /dev/null 2>&1; then
        print_success "HTTPS access is working"
    else
        print_error "HTTPS access is not working"
    fi
    
    # Check HTTP redirect
    print_info "Testing HTTP redirect..."
    if curl -s -I http://$DOMAIN/ | grep -q "301\|302"; then
        print_success "HTTP redirect is working"
    else
        print_warning "HTTP redirect may not be working"
    fi
}

################################################################################
# Firewall Diagnostics
################################################################################

check_firewall() {
    print_header "Firewall Diagnostics"
    
    # Check UFW status
    if ufw status | grep -q "Status: active"; then
        print_success "UFW is active"
        
        # Check rules
        print_info "UFW rules:"
        ufw status numbered | head -20
        
        # Check specific ports
        if ufw status | grep -q "80/tcp"; then
            print_success "Port 80 (HTTP) is allowed"
        else
            print_warning "Port 80 (HTTP) is not allowed"
        fi
        
        if ufw status | grep -q "443/tcp"; then
            print_success "Port 443 (HTTPS) is allowed"
        else
            print_warning "Port 443 (HTTPS) is not allowed"
        fi
        
        if ufw status | grep -q "25345/tcp"; then
            print_success "Port 25345 is allowed"
        else
            print_warning "Port 25345 is not allowed"
        fi
    else
        print_warning "UFW is not active"
    fi
}

################################################################################
# Logs Analysis
################################################################################

check_logs() {
    print_header "Logs Analysis"
    
    # Docker logs
    print_info "Recent Docker logs (last 10 lines):"
    docker logs --tail 10 $CONTAINER_NAME 2>/dev/null || print_warning "Could not retrieve Docker logs"
    
    # Nginx error logs
    print_info "\nRecent Nginx errors (last 10 lines):"
    tail -10 /var/log/nginx/ctrader.error.log 2>/dev/null || print_warning "Could not retrieve Nginx error logs"
    
    # System logs
    print_info "\nRecent system errors (last 10 lines):"
    journalctl -n 10 -p err 2>/dev/null || print_warning "Could not retrieve system logs"
}

################################################################################
# Auto-Fix Options
################################################################################

fix_docker() {
    print_header "Fixing Docker Issues"
    
    print_info "Restarting Docker daemon..."
    systemctl restart docker
    print_success "Docker daemon restarted"
    
    print_info "Restarting container..."
    docker restart $CONTAINER_NAME
    print_success "Container restarted"
}

fix_nginx() {
    print_header "Fixing Nginx Issues"
    
    print_info "Testing Nginx configuration..."
    if nginx -t; then
        print_info "Reloading Nginx..."
        systemctl reload nginx
        print_success "Nginx reloaded"
    else
        print_error "Nginx configuration has errors. Fix them manually."
    fi
}

fix_ssl() {
    print_header "Fixing SSL Issues"
    
    print_info "Renewing certificate..."
    certbot renew --force-renewal
    
    print_info "Reloading Nginx..."
    systemctl reload nginx
    print_success "SSL certificate renewed and Nginx reloaded"
}

fix_firewall() {
    print_header "Fixing Firewall Issues"
    
    print_info "Enabling UFW..."
    ufw --force enable
    
    print_info "Adding firewall rules..."
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 25345/tcp
    
    print_success "Firewall rules configured"
}

################################################################################
# Interactive Menu
################################################################################

show_menu() {
    echo -e "\n${BLUE}Troubleshooting Options:${NC}"
    echo "1. Run all diagnostics"
    echo "2. Check system"
    echo "3. Check Docker"
    echo "4. Check application"
    echo "5. Check Nginx"
    echo "6. Check SSL/HTTPS"
    echo "7. Check network"
    echo "8. Check firewall"
    echo "9. Check logs"
    echo "10. Fix Docker issues"
    echo "11. Fix Nginx issues"
    echo "12. Fix SSL issues"
    echo "13. Fix firewall issues"
    echo "14. Exit"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    check_root
    
    print_header "TradingView Webhook Bridge - Troubleshooting"
    
    while true; do
        show_menu
        read -p "Select option (1-14): " choice
        
        case $choice in
            1) check_system; check_docker; check_application; check_nginx; check_ssl; check_network; check_firewall; check_logs ;;
            2) check_system ;;
            3) check_docker ;;
            4) check_application ;;
            5) check_nginx ;;
            6) check_ssl ;;
            7) check_network ;;
            8) check_firewall ;;
            9) check_logs ;;
            10) fix_docker ;;
            11) fix_nginx ;;
            12) fix_ssl ;;
            13) fix_firewall ;;
            14) print_info "Exiting..."; exit 0 ;;
            *) print_error "Invalid option" ;;
        esac
    done
}

# Run main function
main
