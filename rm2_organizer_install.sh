#!/bin/bash
# reMarkable 2 Article Organizer Installation Script
# Installs to home directory to persist across system updates

set -e

echo "Installing reMarkable 2 Article Organizer..."

# Define directories that persist across updates
RM2_HOME="/home/root/.rm2_organizer"
RM2_BIN="/home/root/bin"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Create persistent directories
echo "Creating directories..."
mkdir -p "$RM2_HOME"
mkdir -p "$RM2_BIN"

# Copy the main script to persistent location
echo "Installing main script..."
cp rm2_organizer.py "$RM2_BIN/"
chmod +x "$RM2_BIN/rm2_organizer.py"

# Copy configuration file if it doesn't exist
if [ ! -f "$RM2_HOME/config.json" ]; then
    echo "Installing default configuration..."
    cp rm2_organizer_config.json "$RM2_HOME/config.json"
else
    echo "Configuration file exists, skipping..."
fi

# Create convenience scripts
echo "Creating convenience scripts..."

# Manual run script
cat > "$RM2_BIN/organize-articles" << 'EOF'
#!/bin/bash
# Manual article organization script
/home/root/bin/rm2_organizer.py --once
EOF
chmod +x "$RM2_BIN/organize-articles"

# Service management script
cat > "$RM2_BIN/rm2-service" << 'EOF'
#!/bin/bash
# Service management script

case "$1" in
    start)
        echo "Starting reMarkable Article Organizer..."
        systemctl start rm2-organizer
        ;;
    stop)
        echo "Stopping reMarkable Article Organizer..."
        systemctl stop rm2-organizer
        ;;
    restart)
        echo "Restarting reMarkable Article Organizer..."
        systemctl restart rm2-organizer
        ;;
    status)
        systemctl status rm2-organizer
        ;;
    install)
        echo "Installing systemd service..."
        /home/root/bin/rm2_organizer.py --install-service
        ;;
    logs)
        echo "=== Application Logs ==="
        tail -n 50 /home/root/.rm2_organizer/organizer.log
        echo ""
        echo "=== System Logs ==="
        journalctl -u rm2-organizer --no-pager -n 20
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|install|logs}"
        exit 1
        ;;
esac
EOF
chmod +x "$RM2_BIN/rm2-service"

# Add bin directory to PATH if not already there
if ! grep -q "/home/root/bin" /home/root/.bashrc; then
    echo 'export PATH="$HOME/bin:$PATH"' >> /home/root/.bashrc
    echo "Added ~/bin to PATH in .bashrc"
fi

# Add auto-recovery to .bashrc
echo "Setting up auto-recovery after updates..."
if ! grep -q "rm2_organizer auto-recovery" /home/root/.bashrc; then
    cat >> /home/root/.bashrc << 'EOF'

# rm2_organizer auto-recovery after system updates
if [ -f /home/root/bin/rm2_organizer.py ] && [ ! -f /etc/systemd/system/rm2-organizer.service ]; then
    echo "🔧 Detected missing reMarkable Article Organizer service after update..."
    echo "🔄 Auto-reinstalling service..."
    /home/root/bin/rm2_organizer.py --install-service >/dev/null 2>&1
    systemctl start rm2-organizer >/dev/null 2>&1
    echo "✅ reMarkable Article Organizer restored!"
fi
EOF
    echo "Added auto-recovery to .bashrc"
fi

# Install the systemd service
echo "Installing systemd service..."
"$RM2_BIN/rm2_organizer.py" --install-service

# Create auto-reinstall script for after updates
echo "Creating post-update reinstall script..."
cat > "$RM2_HOME/reinstall-after-update.sh" << 'EOF'
#!/bin/bash
# Run this script after reMarkable system updates to reinstall the service

echo "Reinstalling reMarkable Article Organizer after system update..."

# Reinstall systemd service (since /etc/systemd/system gets wiped)
/home/root/bin/rm2_organizer.py --install-service

# Start the service
systemctl start rm2-organizer

echo "Reinstallation complete!"
echo "Check status with: rm2-service status"
EOF
chmod +x "$RM2_HOME/reinstall-after-update.sh"

# Start the service
echo "Starting service..."
systemctl start rm2-organizer

echo ""
echo "🎉 Installation complete!"
echo ""
echo "📁 Files installed to: $RM2_HOME"
echo "📝 Configuration: $RM2_HOME/config.json"
echo "📋 Logs: $RM2_HOME/organizer.log" 
echo "📊 Reading state: $RM2_HOME/reading_state.json"
echo ""
echo "🔧 Management commands:"
echo "  rm2-service start|stop|restart|status|logs"
echo "  organize-articles  (run once manually)"
echo ""
echo "📱 After system updates, run:"
echo "  $RM2_HOME/reinstall-after-update.sh"
echo ""
echo "✅ Service is now running. Check status with:"
echo "  rm2-service status"