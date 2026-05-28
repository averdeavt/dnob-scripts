#!/usr/bin/env bash
# Bitfocus Companion — Desktop Service Installer
# For Linux Mint MATE (and other Ubuntu/Debian-based desktops)
#
# Usage:
#   sudo bash install-companion.sh             — install
#   sudo bash install-companion.sh --uninstall — remove Companion (keeps config/data)
#
# Before running: download Companion Linux x64 tar.gz from https://user.bitfocus.io/download
# and save it to ~/Downloads — no renaming needed, any version will be detected automatically.

set -e

# ── Checks ────────────────────────────────────────────────────────────────────

if [ ! "$BASH_VERSION" ]; then
    echo "ERROR: Run this script with bash: sudo bash install-companion.sh"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run with sudo."
    echo "  Usage: sudo bash install-companion.sh"
    exit 1
fi

if ! command -v apt-get &>/dev/null; then
    echo "ERROR: This script requires a Debian/Ubuntu-based system."
    exit 1
fi

ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
    echo "ERROR: Unsupported architecture: $ARCH"
    exit 1
fi

# ── Resolve the real user who called sudo ─────────────────────────────────────

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# ── Uninstall ─────────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--uninstall" ]]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Bitfocus Companion — Uninstall"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo " This will remove:"
    echo "   - Companion binaries (/opt/companion)"
    echo "   - systemd service"
    echo "   - udev rules"
    echo "   - Desktop shortcut and launcher script"
    echo "   - companion system user"
    echo ""
    echo " This will NOT remove:"
    echo "   - Your Companion config and data (/etc/companion)"
    echo ""
    read -rp "Continue? [y/N] " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    echo ""
    echo "Stopping and disabling service..."
    systemctl stop companion 2>/dev/null || true
    systemctl disable companion 2>/dev/null || true
    rm -f /etc/systemd/system/companion.service
    systemctl daemon-reload

    echo "Removing binaries..."
    rm -rf /opt/companion

    echo "Removing udev rules..."
    rm -f /etc/udev/rules.d/50-companion.rules
    udevadm control --reload-rules

    echo "Removing desktop shortcut and launcher..."
    rm -f "$REAL_HOME/Desktop/Companion.desktop"
    rm -f /usr/local/bin/companion-status
    rm -f /usr/share/applications/companion.desktop

    echo "Removing companion system user..."
    userdel companion 2>/dev/null || true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Uninstall complete."
    echo " Your config and data in /etc/companion is untouched."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

# ── Configuration ─────────────────────────────────────────────────────────────

COMPANION_ARCH="x64"
if [ "$ARCH" = "arm64" ]; then
    COMPANION_ARCH="arm64"
fi

INSTALL_DIR="/opt/companion"
CONFIG_DIR="/etc/companion"
SERVICE_FILE="/etc/systemd/system/companion.service"
UDEV_FILE="/etc/udev/rules.d/50-companion.rules"
LAUNCHER_SCRIPT="/usr/local/bin/companion-status"
ADMIN_PORT="8000"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Bitfocus Companion — Desktop Service Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " Install dir   : $INSTALL_DIR"
echo " Config dir    : $CONFIG_DIR"
echo " Web UI port   : $ADMIN_PORT"
echo " Architecture  : $COMPANION_ARCH"
echo " Desktop user  : $REAL_USER"
echo ""
read -rp "Continue? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# ── Dependencies ──────────────────────────────────────────────────────────────

echo ""
echo "[ 1/8 ] Installing dependencies..."
apt-get update -q
apt-get install -yq libusb-1.0-0-dev libudev-dev wget curl zenity
apt-get clean

# ── Download ──────────────────────────────────────────────────────────────────

echo ""
echo "[ 2/8 ] Looking for Companion download in ~/Downloads..."

# Accept any companion linux tar.gz regardless of version naming
TARBALL=$(ls "$REAL_HOME/Downloads"/companion-linux-${COMPANION_ARCH}-*.tar.gz 2>/dev/null | sort -V | tail -n1)

if [ -n "$TARBALL" ] && [ -f "$TARBALL" ]; then
    # Extract version from filename for display purposes
    COMPANION_VERSION=$(basename "$TARBALL" | grep -oP '\d+\.\d+\.\d+' | head -n1)
    echo "        Found: $TARBALL"
    [ -n "$COMPANION_VERSION" ] && echo "        Version: $COMPANION_VERSION"
else
    echo ""
    echo "  No Companion download found in $REAL_HOME/Downloads/"
    echo "  Looking for any file matching: companion-linux-${COMPANION_ARCH}-*.tar.gz"
    echo ""
    echo "  The Bitfocus download portal requires a free account login."
    echo "  Please:"
    echo "    1. Go to https://user.bitfocus.io/download"
    echo "    2. Log in and download the Linux ${COMPANION_ARCH} tar.gz"
    echo "    3. Save it to your Downloads folder (do not rename it)"
    echo "    4. Re-run this script."
    echo ""
    exit 1
fi

# ── Install files ─────────────────────────────────────────────────────────────

echo ""
echo "[ 3/8 ] Installing files to $INSTALL_DIR..."

if systemctl is-active --quiet companion 2>/dev/null; then
    echo "        Stopping existing Companion service..."
    systemctl stop companion
fi

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$TARBALL" -C "$INSTALL_DIR" --strip-components=1
chmod +x "$INSTALL_DIR/companion_headless.sh" 2>/dev/null || true

# ── System user ───────────────────────────────────────────────────────────────

echo ""
echo "[ 4/8 ] Setting up companion system user..."

if id -u companion &>/dev/null; then
    echo "        User 'companion' already exists, skipping."
else
    adduser --system --group --no-create-home companion
    echo "        Created system user 'companion'."
fi

# ── Config directory ──────────────────────────────────────────────────────────

echo ""
echo "[ 5/8 ] Setting up config directory at $CONFIG_DIR..."
mkdir -p "$CONFIG_DIR"
chown -R companion:companion "$CONFIG_DIR"
chown -R companion:companion "$INSTALL_DIR"

# ── udev rules ────────────────────────────────────────────────────────────────

echo ""
echo "[ 6/8 ] Installing udev rules for Stream Deck USB access..."

cat > "$UDEV_FILE" << 'EOF'
# Elgato Stream Deck - Bitfocus Companion
SUBSYSTEM=="input", GROUP="input", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006?", MODE:="666", GROUP="plugdev"
KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006?", MODE:="666", GROUP="plugdev"
EOF

usermod -aG plugdev companion
udevadm control --reload-rules
echo "        Done. Reconnect any Stream Deck devices after install."

# ── systemd service ───────────────────────────────────────────────────────────

echo ""
echo "[ 7/8 ] Installing and enabling systemd service..."

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Bitfocus Companion
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=companion
Environment=COMPANION_IN_SYSTEMD=1
ExecStart=${INSTALL_DIR}/companion_headless.sh --config-dir ${CONFIG_DIR} --admin-address 0.0.0.0 --admin-port ${ADMIN_PORT}
Restart=on-failure
KillSignal=SIGINT
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable companion
systemctl start companion

# ── Launcher script and desktop shortcut ──────────────────────────────────────

echo ""
echo "[ 8/8 ] Creating desktop shortcut for $REAL_USER..."

# Create a launcher script that shows status and opens browser
cat > "$LAUNCHER_SCRIPT" << EOF
#!/usr/bin/env bash
# Companion status checker and launcher

PORT=${ADMIN_PORT}

STATUS=\$(systemctl is-active companion 2>/dev/null)
UPTIME=\$(systemctl show companion --property=ActiveEnterTimestamp --value 2>/dev/null | sed 's/ [A-Z]*$//')

if [ "\$STATUS" = "active" ]; then
    zenity --question \\
        --title="Bitfocus Companion" \\
        --text="<b>Companion is running</b>\n\nStarted: \$UPTIME\n\nOpen the web interface now?" \\
        --ok-label="Open" \\
        --cancel-label="Close" \\
        --width=320 2>/dev/null
    if [ \$? -eq 0 ]; then
        xdg-open "http://localhost:\$PORT"
    fi
else
    zenity --question \\
        --title="Bitfocus Companion" \\
        --text="<b>Companion is not running</b>\n\nStatus: \$STATUS\n\nWould you like to start it?" \\
        --ok-label="Start Companion" \\
        --cancel-label="Close" \\
        --width=320 2>/dev/null
    if [ \$? -eq 0 ]; then
        pkexec systemctl start companion
        sleep 2
        xdg-open "http://localhost:\$PORT"
    fi
fi
EOF

chmod +x "$LAUNCHER_SCRIPT"

# Desktop shortcut
mkdir -p "$REAL_HOME/Desktop"
cat > "$REAL_HOME/Desktop/Companion.desktop" << EOF
[Desktop Entry]
Name=Companion
Comment=Bitfocus Companion
Exec=$LAUNCHER_SCRIPT
Type=Application
Terminal=false
Categories=AudioVideo;
EOF

chmod +x "$REAL_HOME/Desktop/Companion.desktop"
chown "$REAL_USER:$REAL_USER" "$REAL_HOME/Desktop/Companion.desktop"

# Also add to application menu
cat > /usr/share/applications/companion.desktop << EOF
[Desktop Entry]
Name=Companion
Comment=Bitfocus Companion
Exec=$LAUNCHER_SCRIPT
Type=Application
Terminal=false
Categories=AudioVideo;
EOF

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " Companion is running as a system service."
echo " Web UI: http://localhost:${ADMIN_PORT}"
echo ""
echo " A 'Companion' shortcut has been placed on the desktop."
echo " Clicking it shows service status and opens the web UI."
echo ""
echo " Useful commands:"
echo "   sudo systemctl status companion   — check service"
echo "   sudo systemctl restart companion  — restart"
echo "   sudo journalctl -u companion -f   — live logs"
echo "   sudo bash install-companion.sh --uninstall"
echo ""
    rm -f /etc/udev/rules.d/50-companion.rules
    udevadm control --reload-rules

    echo "Removing desktop shortcut and launcher..."
    rm -f "$REAL_HOME/Desktop/Companion.desktop"
    rm -f /usr/local/bin/companion-status
    rm -f /usr/share/applications/companion.desktop

    echo "Removing companion system user..."
    userdel companion 2>/dev/null || true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Uninstall complete."
    echo " Your config and data in /etc/companion is untouched."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi

# ── Configuration ─────────────────────────────────────────────────────────────

COMPANION_ARCH="x64"
if [ "$ARCH" = "arm64" ]; then
    COMPANION_ARCH="arm64"
fi

INSTALL_DIR="/opt/companion"
CONFIG_DIR="/etc/companion"
SERVICE_FILE="/etc/systemd/system/companion.service"
UDEV_FILE="/etc/udev/rules.d/50-companion.rules"
LAUNCHER_SCRIPT="/usr/local/bin/companion-status"
ADMIN_PORT="8000"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Bitfocus Companion — Desktop Service Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " Install dir   : $INSTALL_DIR"
echo " Config dir    : $CONFIG_DIR"
echo " Web UI port   : $ADMIN_PORT"
echo " Architecture  : $COMPANION_ARCH"
echo " Desktop user  : $REAL_USER"
echo ""
read -rp "Continue? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# ── Dependencies ──────────────────────────────────────────────────────────────

echo ""
echo "[ 1/8 ] Installing dependencies..."
apt-get update -q
apt-get install -yq libusb-1.0-0-dev libudev-dev wget curl zenity
apt-get clean

# ── Download ──────────────────────────────────────────────────────────────────

echo ""
echo "[ 2/8 ] Looking for Companion download in ~/Downloads..."

# Accept any companion linux tar.gz regardless of version naming
TARBALL=$(ls "$REAL_HOME/Downloads"/companion-linux-${COMPANION_ARCH}-*.tar.gz 2>/dev/null | sort -V | tail -n1)

if [ -n "$TARBALL" ] && [ -f "$TARBALL" ]; then
    # Extract version from filename for display purposes
    COMPANION_VERSION=$(basename "$TARBALL" | grep -oP '\d+\.\d+\.\d+' | head -n1)
    echo "        Found: $TARBALL"
    [ -n "$COMPANION_VERSION" ] && echo "        Version: $COMPANION_VERSION"
else
    echo ""
    echo "  No Companion download found in $REAL_HOME/Downloads/"
    echo "  Looking for any file matching: companion-linux-${COMPANION_ARCH}-*.tar.gz"
    echo ""
    echo "  The Bitfocus download portal requires a free account login."
    echo "  Please:"
    echo "    1. Go to https://user.bitfocus.io/download"
    echo "    2. Log in and download the Linux ${COMPANION_ARCH} tar.gz"
    echo "    3. Save it to your Downloads folder (do not rename it)"
    echo "    4. Re-run this script."
    echo ""
    exit 1
fi

# ── Install files ─────────────────────────────────────────────────────────────

echo ""
echo "[ 3/8 ] Installing files to $INSTALL_DIR..."

if systemctl is-active --quiet companion 2>/dev/null; then
    echo "        Stopping existing Companion service..."
    systemctl stop companion
fi

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$TARBALL" -C "$INSTALL_DIR" --strip-components=1
chmod +x "$INSTALL_DIR/companion_headless.sh" 2>/dev/null || true

# ── System user ───────────────────────────────────────────────────────────────

echo ""
echo "[ 4/8 ] Setting up companion system user..."

if id -u companion &>/dev/null; then
    echo "        User 'companion' already exists, skipping."
else
    adduser --system --group --no-create-home companion
    echo "        Created system user 'companion'."
fi

# ── Config directory ──────────────────────────────────────────────────────────

echo ""
echo "[ 5/8 ] Setting up config directory at $CONFIG_DIR..."
mkdir -p "$CONFIG_DIR"
chown -R companion:companion "$CONFIG_DIR"
chown -R companion:companion "$INSTALL_DIR"

# ── udev rules ────────────────────────────────────────────────────────────────

echo ""
echo "[ 6/8 ] Installing udev rules for Stream Deck USB access..."

cat > "$UDEV_FILE" << 'EOF'
# Elgato Stream Deck - Bitfocus Companion
SUBSYSTEM=="input", GROUP="input", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006?", MODE:="666", GROUP="plugdev"
KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006?", MODE:="666", GROUP="plugdev"
EOF

usermod -aG plugdev companion
udevadm control --reload-rules
echo "        Done. Reconnect any Stream Deck devices after install."

# ── systemd service ───────────────────────────────────────────────────────────

echo ""
echo "[ 7/8 ] Installing and enabling systemd service..."

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Bitfocus Companion
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=companion
Environment=COMPANION_IN_SYSTEMD=1
ExecStart=${INSTALL_DIR}/companion_headless.sh --config-dir ${CONFIG_DIR} --admin-address 0.0.0.0 --admin-port ${ADMIN_PORT}
Restart=on-failure
KillSignal=SIGINT
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable companion
systemctl start companion

# ── Launcher script and desktop shortcut ──────────────────────────────────────

echo ""
echo "[ 8/8 ] Creating desktop shortcut for $REAL_USER..."

# Create a launcher script that shows status and opens browser
cat > "$LAUNCHER_SCRIPT" << EOF
#!/usr/bin/env bash
# Companion status checker and launcher

PORT=${ADMIN_PORT}

STATUS=\$(systemctl is-active companion 2>/dev/null)
UPTIME=\$(systemctl show companion --property=ActiveEnterTimestamp --value 2>/dev/null | sed 's/ [A-Z]*$//')

if [ "\$STATUS" = "active" ]; then
    zenity --question \\
        --title="Bitfocus Companion" \\
        --text="<b>Companion is running</b>\n\nStarted: \$UPTIME\n\nOpen the web interface now?" \\
        --ok-label="Open" \\
        --cancel-label="Close" \\
        --width=320 2>/dev/null
    if [ \$? -eq 0 ]; then
        xdg-open "http://localhost:\$PORT"
    fi
else
    zenity --question \\
        --title="Bitfocus Companion" \\
        --text="<b>Companion is not running</b>\n\nStatus: \$STATUS\n\nWould you like to start it?" \\
        --ok-label="Start Companion" \\
        --cancel-label="Close" \\
        --width=320 2>/dev/null
    if [ \$? -eq 0 ]; then
        pkexec systemctl start companion
        sleep 2
        xdg-open "http://localhost:\$PORT"
    fi
fi
EOF

chmod +x "$LAUNCHER_SCRIPT"

# Desktop shortcut
mkdir -p "$REAL_HOME/Desktop"
cat > "$REAL_HOME/Desktop/Companion.desktop" << EOF
[Desktop Entry]
Name=Companion
Comment=Bitfocus Companion
Exec=$LAUNCHER_SCRIPT
Type=Application
Terminal=false
Categories=AudioVideo;
EOF

chmod +x "$REAL_HOME/Desktop/Companion.desktop"
chown "$REAL_USER:$REAL_USER" "$REAL_HOME/Desktop/Companion.desktop"

# Also add to application menu
cat > /usr/share/applications/companion.desktop << EOF
[Desktop Entry]
Name=Companion
Comment=Bitfocus Companion
Exec=$LAUNCHER_SCRIPT
Type=Application
Terminal=false
Categories=AudioVideo;
EOF

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " Companion is running as a system service."
echo " Web UI: http://localhost:${ADMIN_PORT}"
echo ""
echo " A 'Companion' shortcut has been placed on the desktop."
echo " Clicking it shows service status and opens the web UI."
echo ""
echo " Useful commands:"
echo "   sudo systemctl status companion   — check service"
echo "   sudo systemctl restart companion  — restart"
echo "   sudo journalctl -u companion -f   — live logs"
echo "   sudo bash install-companion.sh --uninstall"
echo ""
