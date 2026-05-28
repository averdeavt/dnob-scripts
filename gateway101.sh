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
    else
      echo "[DISABLE] $name ($dev)"
      nmcli connection modify "$name" ipv4.never-default yes
    fi
  fi
done

echo
echo "Removing existing default routes..."

ip route | grep '^default' | while read line; do
  dev=$(echo "$line" | awk '{print $5}')
  if [ "$dev" != "$PRIMARY_DEV" ]; then
    echo "Deleting default route on $dev"
    ip route del default dev "$dev" 2>/dev/null
  fi
done

echo
echo "Restarting NetworkManager..."
systemctl restart NetworkManager

echo
echo "=== Result ==="
ip route | grep default
