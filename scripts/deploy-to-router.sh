#!/bin/sh
# ==============================================================================
# One-Line Deployment Script to Provision / Update OpenWrt Travel Router
# Usage: ./deploy-to-router.sh [ROUTER_IP]
# ==============================================================================

set -e

ROUTER_IP="${1:-10.8.0.2}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[*] Connecting to OpenWrt router at $ROUTER_IP..."

# Check connectivity
if ! ping -c 1 -W 2 "$ROUTER_IP" >/dev/null 2>&1; then
    echo "[-] Cannot reach $ROUTER_IP. Ensure you are connected to the router Wi-Fi or WireGuard tunnel."
    exit 1
fi

echo "[*] Transferring Travel Portal files..."
# Upload CGI API and Captive Hook
cat "$SCRIPT_DIR/router/www/cgi-bin/portal-api" | ssh -o StrictHostKeyChecking=no "root@$ROUTER_IP" "cat > /www/cgi-bin/portal-api && chmod +x /www/cgi-bin/portal-api"
cat "$SCRIPT_DIR/router/www/cgi-bin/captive" | ssh -o StrictHostKeyChecking=no "root@$ROUTER_IP" "cat > /www/cgi-bin/captive && chmod +x /www/cgi-bin/captive"

# Upload Gateway Switcher
cat "$SCRIPT_DIR/router/bin/hotspot-mode" | ssh -o StrictHostKeyChecking=no "root@$ROUTER_IP" "cat > /usr/bin/hotspot-mode && chmod +x /usr/bin/hotspot-mode"

# Upload Gzipped Portal UI
gzip -9 -c "$SCRIPT_DIR/router/www/index.html" | ssh -o StrictHostKeyChecking=no "root@$ROUTER_IP" "cat > /etc/portal.html.gz"

# Create CGI portal launcher and index redirect
ssh -o StrictHostKeyChecking=no "root@$ROUTER_IP" 'cat << "EOF" > /www/cgi-bin/portal
#!/bin/sh
echo "Content-Type: text/html; charset=utf-8"
echo "Content-Encoding: gzip"
echo "Cache-Control: no-cache, no-store, must-revalidate"
echo ""
cat /etc/portal.html.gz
EOF
chmod +x /www/cgi-bin/portal

cat << "EOF" > /www/index.html
<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0; url=/cgi-bin/portal"></head><body><script>window.location.replace("/cgi-bin/portal");</script></body></html>
EOF
'

# Install boot persistence in rc.local
cat "$SCRIPT_DIR/router/etc/rc.local" | ssh -o StrictHostKeyChecking=no "root@$ROUTER_IP" "cat > /etc/rc.local && chmod +x /etc/rc.local"

echo "[+] Deployment complete! Travel Gateway is live at http://$ROUTER_IP/"
