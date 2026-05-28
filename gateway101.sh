#!/bin/bash

# === CONFIG ===
PRIMARY_DEV="enp6s20"   # VLAN 101 interface

echo "=== Fixing default routes ==="
echo "Primary interface: $PRIMARY_DEV"
echo

nmcli -t -f NAME,DEVICE connection show | while IFS=: read name dev; do
  if [ -n "$dev" ]; then
    if [ "$dev" = "$PRIMARY_DEV" ]; then
      echo "[KEEP]   $name ($dev)"
      nmcli connection modify "$name" ipv4.never-default no
      nmcli connection modify "$name" ipv4.route-metric 101
    else
      echo "[DISABLE] $name ($dev)"
      nmcli connection modify "$name" ipv4.never-default yes
      nmcli connection modify "$name" ipv4.ignore-auto-routes yes
    fi
  fi
done

echo
echo "Removing ALL default routes..."
ip route del default 2>/dev/null

echo
echo "Restarting NetworkManager..."
systemctl restart NetworkManager

echo
echo "=== Result ==="
ip route | grep default

COUNT=$(ip route | grep -c '^default')

if [ "$COUNT" -eq 1 ]; then
  echo "✅ Success: exactly one default route"
else
  echo "❌ Warning: $COUNT default routes detected"
fi
