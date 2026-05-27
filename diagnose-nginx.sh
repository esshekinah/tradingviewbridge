#!/bin/bash

# Diagnostic script to check Nginx configuration and port 80 issue

echo "=========================================="
echo "NGINX DIAGNOSTIC REPORT"
echo "=========================================="
echo ""

echo "1. Check Nginx is running:"
sudo systemctl status nginx
echo ""

echo "2. Check Nginx configuration syntax:"
sudo nginx -t
echo ""

echo "3. Check listening ports:"
sudo netstat -tlnp | grep -E ":80|:25345" || sudo ss -tlnp | grep -E ":80|:25345"
echo ""

echo "4. Check Nginx processes:"
ps aux | grep nginx | grep -v grep
echo ""

echo "5. Check current Nginx config for ctrader domain:"
sudo cat /etc/nginx/sites-available/ctrader.emmanuelshekinah.co.za 2>/dev/null || echo "Config not found"
echo ""

echo "6. Check if site is enabled:"
ls -la /etc/nginx/sites-enabled/ | grep ctrader
echo ""

echo "7. Check Nginx main config includes:"
sudo grep -n "include" /etc/nginx/nginx.conf | head -20
echo ""

echo "8. Test port 80 locally:"
curl -v http://localhost/health 2>&1 | head -20
echo ""

echo "9. Test port 25345 locally:"
curl -v http://localhost:25345/health 2>&1 | head -20
echo ""

echo "10. Check Nginx error log (last 20 lines):"
sudo tail -20 /var/log/nginx/error.log
echo ""

echo "11. Check if Dokploy is managing Nginx:"
ls -la /etc/nginx/sites-available/ | grep -i dokploy
echo ""

echo "12. Check Docker containers:"
docker ps | grep -E "tradingview|webhook"
echo ""

echo "=========================================="
echo "END DIAGNOSTIC REPORT"
echo "=========================================="
