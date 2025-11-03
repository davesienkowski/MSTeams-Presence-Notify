#!/bin/bash
# Quick installation script for MS Teams Presence - Integrated Solution
# Raspberry Pi + Unicorn HAT + Web Dashboard + Push Notifications + Home Assistant

set -e  # Exit on error

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  MS Teams Presence - Complete Integrated Solution Installer   ║"
echo "║  Web Dashboard + Push Notifications + Home Assistant          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo "⚠️  Warning: This doesn't appear to be a Raspberry Pi"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install system dependencies
echo "📦 Installing system dependencies..."
sudo apt-get install -y python3-pip python3-dev git

# Install Unicorn HAT library
echo "🌈 Installing Unicorn HAT library..."
if ! python3 -c "import unicornhat" 2>/dev/null; then
    echo "Installing Unicorn HAT via Pimoroni installer..."
    curl -sS https://get.pimoroni.com/unicornhat | bash -s - -y
else
    echo "✓ Unicorn HAT library already installed"
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
cd "$(dirname "$0")"
sudo pip3 install -r requirements_integrated.txt

# Create configuration file if it doesn't exist
if [ ! -f config.yaml ]; then
    echo "📝 Creating configuration file..."
    cp config.yaml config.yaml.example 2>/dev/null || true

    # Prompt for configuration
    read -p "Enter your Windows PC IP address (e.g., 192.168.1.100): " PC_IP
    read -p "Enter a unique ntfy topic name (e.g., myteamspresence_$(whoami)_$RANDOM): " NTFY_TOPIC

    # Update config file
    sed -i "s/YOUR_PC_IP/$PC_IP/g" config.yaml
    sed -i "s/myteamspresence/$NTFY_TOPIC/g" config.yaml

    echo "✓ Configuration file created"
else
    echo "✓ Configuration file already exists"
fi

# Get Raspberry Pi IP
RPI_IP=$(hostname -I | awk '{print $1}')

# Test connection to Windows PC
echo ""
echo "🔍 Testing connection to Windows PC..."
if timeout 3 curl -s "http://$PC_IP:8080/status" > /dev/null 2>&1; then
    echo "✓ Successfully connected to Teams status server"
else
    echo "⚠️  Warning: Cannot connect to Teams status server at http://$PC_IP:8080"
    echo "   Make sure the PowerShell server is running on your Windows PC"
fi

# Offer to install as systemd service
echo ""
read -p "Install as systemd service (auto-start on boot)? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$|^$ ]]; then
    echo "📝 Creating systemd service..."

    sudo tee /etc/systemd/system/teams-presence.service > /dev/null <<EOF
[Unit]
Description=MS Teams Presence Monitor - Integrated
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/python3 $(pwd)/teams_status_integrated.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable teams-presence.service
    sudo systemctl start teams-presence.service

    echo "✓ Service installed and started"
    echo ""
    echo "Service commands:"
    echo "  Status:  sudo systemctl status teams-presence"
    echo "  Stop:    sudo systemctl stop teams-presence"
    echo "  Restart: sudo systemctl restart teams-presence"
    echo "  Logs:    sudo journalctl -u teams-presence -f"
else
    echo "Skipping service installation"
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Installation Complete! 🎉                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Access your dashboard at: http://$RPI_IP:5000"
echo ""
echo "📱 To receive push notifications:"
echo "   1. Install ntfy app on your phone (iOS/Android)"
echo "   2. Subscribe to topic: $NTFY_TOPIC"
echo ""
echo "🏠 For Home Assistant integration:"
echo "   1. Edit config.yaml and enable homeassistant section"
echo "   2. Configure your MQTT broker details"
echo "   3. Restart the service"
echo ""
echo "📚 See MOBILE_INTEGRATION.md for complete setup guide"
echo ""

# Offer to test
if [ -z "$(systemctl is-active teams-presence 2>/dev/null)" ]; then
    echo ""
    read -p "Run test now? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$|^$ ]]; then
        echo "Starting Teams presence monitor..."
        echo "Press Ctrl+C to stop"
        echo ""
        sudo python3 teams_status_integrated.py
    fi
else
    echo "Service is running! Check status with: sudo systemctl status teams-presence"
fi
