# install Companion

Quick check if companion is already installed
On the VM, run:

```
systemctl status companion
```

Script - installasjon Companion:
```
curl -fsSL https://raw.githubusercontent.com/averdeavt/dnob-scripts/main/install-companion.sh -o /tmp/install-companion.sh && sudo bash /tmp/install-companion.sh
```

### Remove extra gateways (keep VLAN 101)

Fixes multiple default routes by keeping only the VLAN 101 interface as gateway:

```bash
curl -fsSL https://raw.githubusercontent.com/averdeavt/dnob-scripts/main/gateway101.sh -o /tmp/gateway101.sh && sudo bash /tmp/gateway101.sh
```

Cache safe
```
curl -fsSL "https://raw.githubusercontent.com/averdeavt/dnob-scripts/main/gateway101.sh?nocache=$(date +%s)" -o /tmp/gateway101.sh && sudo bash /tmp/gateway101.sh
```
