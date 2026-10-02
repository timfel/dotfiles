#!/usr/bin/env bash
# ==============================================================================
# Dotfiles Setup Script: Wake-on-LAN Setup (Fedora)
# ==============================================================================
set -euo pipefail

# Configuration variables
SSH_PORT="22"
IDLE_THRESHOLD_MINUTES=30

echo "[+] Step 1: Enabling Wake-on-LAN in NetworkManager..."
ETH_CONN=$(nmcli -t -f NAME,TYPE connection show --active | grep ethernet | head -n1 | cut -d: -f1 || true)

if [ -n "$ETH_CONN" ]; then
    echo "    Found active Ethernet connection: '$ETH_CONN'"
    sudo nmcli connection modify "$ETH_CONN" 802-3-ethernet.wake-on-lan magic
    echo "    Wake-on-LAN (magic packet) enabled for '$ETH_CONN'."
else
    echo "    [!] Warning: No active wired Ethernet connection detected via nmcli."
    echo "        Please enable WoL manually on your Ethernet interface once connected."
fi

echo "[+] Step 2: Creating idle monitor script (/usr/local/bin/check_idle.sh)..."
sudo tee /usr/local/bin/check_idle.sh > /dev/null << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Service ports to check for active connections
SSH_PORT="__SSH_PORT__"
IDLE_LIMIT="__IDLE_LIMIT__"
STATE_FILE="/tmp/machine_idle_minutes"

# 1. Physical Keyboard Check
if ls /dev/input/by-id/*-kbd 1>/dev/null 2>&1; then
    echo 0 > "$STATE_FILE"
    exit 0
fi

# 2. CPU Load Check (< 10% total capacity across all cores)
LOAD_1MIN=$(awk '{print $1}' /proc/loadavg)
CORES=$(nproc)
THRESHOLD=$(awk -v cores="$CORES" 'BEGIN {print cores * 0.10}')

IS_BUSY=$(awk -v ld="$LOAD_1MIN" -v thresh="$THRESHOLD" 'BEGIN {print (ld > thresh) ? 1 : 0}')
if [ "$IS_BUSY" -eq 1 ]; then
    echo 0 > "$STATE_FILE"
    exit 0
fi

# 3. Target Network Traffic Check (SSH & HTTP endpoint)
# Ignores Tailscale daemon, DERP relays, and general system background pings
ACTIVE_CONNS=$(/usr/bin/ss -t -H state established "( sport = :${SSH_PORT} )" | wc -l)
if [ "$ACTIVE_CONNS" -gt 0 ]; then
    echo 0 > "$STATE_FILE"
    exit 0
fi

# Increment idle counter
IDLE_COUNT=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
IDLE_COUNT=$((IDLE_COUNT + 1))
echo "$IDLE_COUNT" > "$STATE_FILE"

# Suspend if idle condition met continuously
if [ "$IDLE_COUNT" -ge "$IDLE_LIMIT" ]; then
    echo 0 > "$STATE_FILE"
    systemctl suspend
fi
EOF

# Inject variables into the created script
sudo sed -i "s/__SSH_PORT__/$SSH_PORT/g" /usr/local/bin/check_idle.sh
sudo sed -i "s/__IDLE_LIMIT__/$IDLE_THRESHOLD_MINUTES/g" /usr/local/bin/check_idle.sh
sudo chmod +x /usr/local/bin/check_idle.sh

echo "[+] Step 3: Setting up systemd timer for minute-by-minute checks..."

# Create systemd Service
sudo tee /etc/systemd/system/machine-idle-check.service > /dev/null << 'EOF'
[Unit]
Description=Machine System Idle Check
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/check_idle.sh
EOF

# Create systemd Timer (runs every minute)
sudo tee /etc/systemd/system/machine-idle-check.timer > /dev/null << 'EOF'
[Unit]
Description=Run Machine Idle Check Every Minute

[Timer]
OnCalendar=*:*
AccuracySec=1s
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "[+] Step 4: Reloading systemd and activating timer..."
sudo systemctl daemon-reload
sudo systemctl enable --now machine-idle-check.timer

echo "[✔] Machine idle setup complete!"
echo "    Check status: systemctl status machine-idle-check.timer"
echo "    View logs:   journalctl -u machine-idle-check.service"
