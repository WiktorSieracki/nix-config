#!/usr/bin/env bash
set -euo pipefail

echo "==> Resetting network..."

echo "--> Restarting NetworkManager"
sudo systemctl restart NetworkManager
sleep 2

if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
  echo "--> Flushing DNS cache (systemd-resolved)"
  sudo resolvectl flush-caches
fi

if systemctl is-active --quiet tailscaled 2>/dev/null; then
  echo "--> Restarting Tailscale"
  sudo systemctl restart tailscaled
  sleep 1
fi

echo ""
echo "==> Network status:"
nmcli -c yes device status
echo ""

echo "--> Testing connectivity"
if ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
  echo "    IP:  OK"
else
  echo "    IP:  FAIL (no route to internet)"
fi

if ping -c 1 -W 3 google.com &>/dev/null; then
  echo "    DNS: OK"
else
  echo "    DNS: FAIL (DNS not resolving)"
fi
