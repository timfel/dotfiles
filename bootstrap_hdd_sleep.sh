#!/usr/bin/env bash
# ==============================================================================
# Dotfiles Setup Script: Debian USB HDD Auto Spin-Down Setup
# ==============================================================================
set -euo pipefail

IDLE_SECONDS=1800 # 30 minutes

echo "[+] Step 1: Installing hd-idle..."
sudo apt-get update
sudo apt-get install -y hd-idle

echo "[+] Step 2: Configuring /etc/default/hd-idle..."
# Backup existing config if present
if [ -f /etc/default/hd-idle ]; then
    sudo cp /etc/default/hd-idle /etc/default/hd-idle.bak
fi

# Write updated default configuration
# -i 1800 sets a default 30-min idle timeout for all attached SCSI/USB disks
sudo tee /etc/default/hd-idle > /dev/null << EOF
# /etc/default/hd-idle configuration

# Start hd-idle daemon on boot
START_HD_IDLE=true

# -i $IDLE_SECONDS: spin down any drive after 30 minutes of no disk I/O
# -l /var/log/hd-idle.log: output operational log
HD_IDLE_OPTS="-i $IDLE_SECONDS -l /var/log/hd-idle.log"
EOF

echo "[+] Step 3: Enabling and restarting hd-idle service..."
sudo systemctl daemon-reload
sudo systemctl enable hd-idle
sudo systemctl restart hd-idle

echo "[✔] Raspberry Pi setup complete!"
echo "    Check status: systemctl status hd-idle"
echo "    View logs:   cat /var/log/hd-idle.log"
