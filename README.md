# dnob-scripts

Quick check if companion is already installed
On the VM, run:

```
systemctl status companion
```

Script - installasjon Companion:
```
curl -fsSL https://raw.githubusercontent.com/averdeavt/dnob-scripts/main/install-companion.sh -o /tmp/install-companion.sh && sudo bash /tmp/install-companion.sh
```

# remove gateways

```
bash <(curl -s https://raw.githubusercontent.com/<your-user>/network-fix/main/fix-routes.sh)
```


