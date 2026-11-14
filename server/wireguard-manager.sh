#!/bin/bash
# ==============================================================================
# WireGuard Server Lifecycle Manager (Home Host)
# ==============================================================================

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

ACTION="${1:-status}"
CONF_DIR="/opt/homebrew/etc/wireguard"
CONF_FILE="${CONF_DIR}/wg0.conf"
WG_QUICK=$(which wg-quick 2>/dev/null || echo "/opt/homebrew/bin/wg-quick")
WG=$(which wg 2>/dev/null || echo "/opt/homebrew/bin/wg")
PLIST_PATH="/Library/LaunchDaemons/com.wireguard.wg0.plist"

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

case "$ACTION" in
    up|start)
        echo "[*] Starting WireGuard server (wg0)..."
        "$WG_QUICK" up wg0
        echo "[+] WireGuard server active:"
        "$WG" show
        ;;
    down|stop)
        echo "[*] Stopping WireGuard server (wg0)..."
        "$WG_QUICK" down wg0
        echo "[+] WireGuard server stopped."
        ;;
    status)
        if "$WG" show 2>/dev/null | grep -q "interface: wg0"; then
            echo "[+] WireGuard wg0 is RUNNING:"
            "$WG" show
        else
            echo "[-] WireGuard wg0 is NOT running."
        fi
        ;;
    restart)
        "$0" stop 2>/dev/null || true
        sleep 1
        "$0" start
        ;;
    install-service)
        echo "[*] Installing persistent LaunchDaemon service..."
        cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.wireguard.wg0</string>
    <key>ProgramArguments</key>
    <array>
        <string>$WG_QUICK</string>
        <string>up</string>
        <string>wg0</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>NetworkState</key>
        <true/>
    </dict>
    <key>StandardErrorPath</key>
    <string>/var/log/wireguard_wg0.log</string>
    <key>StandardOutPath</key>
    <string>/var/log/wireguard_wg0.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF
        chmod 644 "$PLIST_PATH"
        launchctl load -w "$PLIST_PATH"
        echo "[+] Service installed and active across system reboots!"
        ;;
    uninstall-service)
        echo "[*] Removing LaunchDaemon service..."
        launchctl unload -w "$PLIST_PATH" 2>/dev/null || true
        rm -f "$PLIST_PATH"
        "$0" stop 2>/dev/null || true
        echo "[+] Service removed."
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|install-service|uninstall-service}"
        exit 1
        ;;
esac
