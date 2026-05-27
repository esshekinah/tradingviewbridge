#!/bin/bash

################################################################################
# TradingView Webhook Bridge - Monitoring Script
#
# Real-time monitoring of application, Docker, Nginx, and system resources
#
# Usage: bash monitor.sh
################################################################################

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
REFRESH_INTERVAL=5

################################################################################
# Helper Functions
################################################################################

print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  TradingView Webhook Bridge - Real-time Monitoring             ║${NC}"
    echo -e "${BLUE}║  Domain: $DOMAIN                    ║${NC}"
    echo -e "${BLUE}║  Updated: $(date '+%Y-%m-%d %H:%M:%S')                                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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

################################################################################
# System Monitoring
################################################################################

monitor_system() {
    print_section "System Resources"
    
    # CPU Usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
        print_warning "CPU Usage: ${CPU_USAGE}% (HIGH)"
    elif (( $(echo "$CPU_USAGE > 50" | bc -l) )); then
        print_info "CPU Usage: ${CPU_USAGE}%"
    else
        print_success "CPU Usage: ${CPU_USAGE}%"
    fi
    
    # Memory Usage
    MEM_TOTAL=$(free -h | awk 'NR==2 {print $2}')
    MEM_USED=$(free -h | awk 'NR==2 {print $3}')
    MEM_PERCENT=$(free | awk 'NR==2 {printf("%.0f", $3/$2 * 100)}')
    
    if [[ $MEM_PERCENT -gt 80 ]]; then
        print_warning "Memory: ${MEM_USED}/${MEM_TOTAL} (${MEM_PERCENT}% - HIGH)"
    elif [[ $MEM_PERCENT -gt 50 ]]; then
        print_info "Memory: ${MEM_USED}/${MEM_TOTAL} (${MEM_PERCENT}%)"
    else
        print_success "Memory: ${MEM_USED}/${MEM_TOTAL} (${MEM_PERCENT}%)"
    fi
    
    # Disk Usage
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    DISK_PERCENT=${DISK_USAGE%\%}
    
    if [[ $DISK_PERCENT -gt 90 ]]; then
        print_error "Disk: ${DISK_USAGE} (CRITICAL)"
    elif [[ $DISK_PERCENT -gt 80 ]]; then
        print_warning "Disk: ${DISK_USAGE} (HIGH)"
    else
        print_success "Disk: ${DISK_USAGE}"
    fi
    
    # Load Average
    LOAD=$(uptime | awk -F'load average:' '{print $2}')
    print_info "Load Average:${LOAD}"
    
    # Uptime
    UPTIME=$(uptime -p)
    print_info "Uptime: ${UPTIME}"
    
    echo ""
}

################################################################################
# Docker Monitoring
################################################################################

monitor_docker() {
    print_section "Docker Status"
    
    # Docker daemon
    if systemctl is-active --quiet docker; then
        print_success "Docker Daemon: Running"
    else
        print_error "Docker Daemon: Not Running"
        return
    fi
    
    # Container status
    if docker ps --format '{{.Names}}' | grep -q $CONTAINER_NAME; then
        print_success "Container: Running ($CONTAINER_NAME)"
        
        # Container stats
        CONTAINER_ID=$(docker ps --format '{{.ID}}' --filter "name=$CONTAINER_NAME")
        STATS=$(docker stats --no-stream $CONTAINER_ID --format "{{.CPUPerc}} | {{.MemUsage}}")
        print_info "Stats: $STATS"
        
        # Container uptime
        CREATED=$(docker inspect $CONTAINER_ID --format='{{.State.StartedAt}}')
        print_info "Started: $CREATED"
    else
        if docker ps -a --format '{{.Names}}' | grep -q $CONTAINER_NAME; then
            print_error "Container: Stopped ($CONTAINER_NAME)"
        else
            print_error "Container: Not Found ($CONTAINER_NAME)"
        fi
    fi
    
    # Image info
    if docker images --format '{{.Repository}}' | grep -q tradingview; then
        IMAGE_ID=$(docker images --format '{{.ID}}' --filter "reference=*tradingview*" | head -1)
        print_info "Image: $IMAGE_ID"
    fi
    
    echo ""
}

################################################################################
# Application Monitoring
################################################################################

monitor_application() {
    print_section "Application Status"
    
    # Port listening
    if netstat -tlnp 2>/dev/null | grep -q ":$APP_PORT"; then
        print_success "Port $APP_PORT: Listening"
    else
        print_error "Port $APP_PORT: Not Listening"
    fi
    
    # Health check (local)
    if curl -s http://localhost:$APP_PORT/health > /dev/null 2>&1; then
        HEALTH=$(curl -s http://localhost:$APP_PORT/health)
        print_success "Health Endpoint: Responding"
        print_info "Response: $HEALTH"
    else
        print_error "Health Endpoint: Not Responding"
    fi
    
    # HTTPS access
    if curl -s -I https://$DOMAIN/health > /dev/null 2>&1; then
        print_success "HTTPS Access: Working"
    else
        print_error "HTTPS Access: Not Working"
    fi
    
    # Request count (from Nginx logs)
    if [[ -f /var/log/nginx/ctrader.access.log ]]; then
        REQUEST_COUNT=$(wc -l < /var/log/nginx/ctrader.access.log)
        print_info "Total Requests: $REQUEST_COUNT"
        
        # Requests in last hour
        RECENT_REQUESTS=$(grep "$(date -d '1 hour ago' '+%d/%b/%Y:%H')" /var/log/nginx/ctrader.access.log | wc -l)
        print_info "Requests (last hour): $RECENT_REQUESTS"
    fi
    
    echo ""
}

################################################################################
# Nginx Monitoring
################################################################################

monitor_nginx() {
    print_section "Nginx Status"
    
    # Nginx daemon
    if systemctl is-active --quiet nginx; then
        print_success "Nginx: Running"
    else
        print_error "Nginx: Not Running"
        return
    fi
    
    # Configuration
    if nginx -t 2>&1 | grep -q "successful"; then
        print_success "Configuration: Valid"
    else
        print_error "Configuration: Invalid"
    fi
    
    # Listening ports
    if netstat -tlnp 2>/dev/null | grep -q "nginx.*:80"; then
        print_success "Port 80 (HTTP): Listening"
    else
        print_warning "Port 80 (HTTP): Not Listening"
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q "nginx.*:443"; then
        print_success "Port 443 (HTTPS): Listening"
    else
        print_warning "Port 443 (HTTPS): Not Listening"
    fi
    
    # Error count
    if [[ -f /var/log/nginx/ctrader.error.log ]]; then
        ERROR_COUNT=$(grep -c "error" /var/log/nginx/ctrader.error.log 2>/dev/null || echo "0")
        if [[ $ERROR_COUNT -gt 0 ]]; then
            print_warning "Nginx Errors: $ERROR_COUNT"
        else
            print_success "Nginx Errors: None"
        fi
    fi
    
    echo ""
}

################################################################################
# SSL/HTTPS Monitoring
################################################################################

monitor_ssl() {
    print_section "SSL/HTTPS Status"
    
    CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    
    if [[ -f $CERT_PATH ]]; then
        print_success "Certificate: Found"
        
        # Expiry date
        EXPIRY=$(openssl x509 -in $CERT_PATH -noout -enddate | cut -d= -f2)
        print_info "Expiry Date: $EXPIRY"
        
        # Days until expiry
        EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
        
        if [[ $DAYS_LEFT -lt 0 ]]; then
            print_error "Certificate: EXPIRED"
        elif [[ $DAYS_LEFT -lt 7 ]]; then
            print_error "Certificate: Expires in $DAYS_LEFT days (CRITICAL)"
        elif [[ $DAYS_LEFT -lt 30 ]]; then
            print_warning "Certificate: Expires in $DAYS_LEFT days"
        else
            print_success "Certificate: Valid for $DAYS_LEFT days"
        fi
    else
        print_error "Certificate: Not Found"
    fi
    
    # Certbot renewal timer
    if systemctl is-enabled certbot.timer &> /dev/null; then
        print_success "Auto-Renewal: Enabled"
    else
        print_warning "Auto-Renewal: Disabled"
    fi
    
    echo ""
}

################################################################################
# Network Monitoring
################################################################################

monitor_network() {
    print_section "Network Status"
    
    # Internet connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Internet: Connected"
    else
        print_error "Internet: Disconnected"
    fi
    
    # DNS resolution
    if nslookup $DOMAIN &> /dev/null; then
        IP=$(nslookup $DOMAIN 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
        print_success "DNS: Resolving ($IP)"
    else
        print_error "DNS: Not Resolving"
    fi
    
    # Network interfaces
    print_info "Network Interfaces:"
    ip -s link show | grep -E "^[0-9]+:|RX|TX" | head -20
    
    echo ""
}

################################################################################
# Firewall Monitoring
################################################################################

monitor_firewall() {
    print_section "Firewall Status"
    
    if ufw status | grep -q "Status: active"; then
        print_success "UFW: Active"
        
        # Check critical ports
        if ufw status | grep -q "80/tcp"; then
            print_success "Port 80: Allowed"
        else
            print_warning "Port 80: Not Allowed"
        fi
        
        if ufw status | grep -q "443/tcp"; then
            print_success "Port 443: Allowed"
        else
            print_warning "Port 443: Not Allowed"
        fi
        
        if ufw status | grep -q "25345/tcp"; then
            print_success "Port 25345: Allowed"
        else
            print_warning "Port 25345: Not Allowed"
        fi
    else
        print_warning "UFW: Inactive"
    fi
    
    echo ""
}

################################################################################
# Recent Logs
################################################################################

monitor_logs() {
    print_section "Recent Logs (Last 5 lines)"
    
    # Docker logs
    print_info "Docker Logs:"
    docker logs --tail 5 $CONTAINER_NAME 2>/dev/null | sed 's/^/  /' || echo "  (No logs available)"
    
    # Nginx errors
    print_info "\nNginx Errors:"
    tail -5 /var/log/nginx/ctrader.error.log 2>/dev/null | sed 's/^/  /' || echo "  (No errors)"
    
    echo ""
}

################################################################################
# Summary
################################################################################

print_summary() {
    print_section "Quick Summary"
    
    # Overall status
    ISSUES=0
    
    # Check critical services
    if ! systemctl is-active --quiet docker; then
        print_error "Docker is not running"
        ((ISSUES++))
    fi
    
    if ! systemctl is-active --quiet nginx; then
        print_error "Nginx is not running"
        ((ISSUES++))
    fi
    
    if ! docker ps --format '{{.Names}}' | grep -q $CONTAINER_NAME; then
        print_error "Application container is not running"
        ((ISSUES++))
    fi
    
    if ! curl -s http://localhost:$APP_PORT/health > /dev/null 2>&1; then
        print_error "Application health check failed"
        ((ISSUES++))
    fi
    
    if [[ $ISSUES -eq 0 ]]; then
        print_success "All systems operational"
    else
        print_warning "Found $ISSUES issue(s) - review above"
    fi
    
    echo ""
    echo -e "${BLUE}Press Ctrl+C to exit. Refreshing in ${REFRESH_INTERVAL}s...${NC}"
}

################################################################################
# Main Loop
################################################################################

main() {
    while true; do
        print_header
        monitor_system
        monitor_docker
        monitor_application
        monitor_nginx
        monitor_ssl
        monitor_network
        monitor_firewall
        monitor_logs
        print_summary
        
        sleep $REFRESH_INTERVAL
    done
}

# Run main function
main
