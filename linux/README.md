# MS Teams Status Push Client for Linux

Monitors Microsoft Teams logs and pushes status updates to a Raspberry Pi server.

## Prerequisites

- Python 3.6+
- `requests` library

## Installation

```bash
# Install the requests library
pip3 install requests

# Or using your distribution's package manager
# Debian/Ubuntu:
sudo apt install python3-requests

# Fedora:
sudo dnf install python3-requests

# Arch Linux:
sudo pacman -S python-requests
```

## Usage

```bash
# Basic usage (uses default IP and port)
python3 TeamsPushClient.py

# Specify custom Raspberry Pi IP
python3 TeamsPushClient.py --ip 192.168.1.100

# Specify custom port
python3 TeamsPushClient.py --port 9090

# Change poll interval (seconds)
python3 TeamsPushClient.py --interval 10

# Enable verbose output
python3 TeamsPushClient.py --verbose

# Full example with all options
python3 TeamsPushClient.py --ip 192.168.1.100 --port 8080 --interval 5 --verbose
```

## Command Line Options

| Option | Default | Description |
|--------|---------|-------------|
| `--ip` | 192.168.50.137 | Raspberry Pi IP address |
| `--port` | 8080 | Server port |
| `--interval` | 5 | Poll interval in seconds |
| `--verbose` | false | Enable debug output |

## Teams Log Locations

The client checks these locations for Teams logs:

- **New Teams**: `~/.local/share/Microsoft/Teams/Logs`
- **Classic Teams**: `~/.config/Microsoft/Microsoft Teams/logs.txt`
- **Snap**: `~/snap/teams/current/.config/Microsoft/Microsoft Teams/logs.txt`
- **Flatpak**: `~/.var/app/com.microsoft.Teams/config/Microsoft/Microsoft Teams/logs.txt`

## Running as a Systemd Service

To run the client automatically at login:

1. Create a systemd user service file:

```bash
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/teams-status-client.service << 'EOF'
[Unit]
Description=MS Teams Status Push Client
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /path/to/TeamsPushClient.py --ip 192.168.50.137
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF
```

2. Enable and start the service:

```bash
# Reload systemd to recognize new service
systemctl --user daemon-reload

# Enable to start at login
systemctl --user enable teams-status-client

# Start the service now
systemctl --user start teams-status-client
```

3. Manage the service:

```bash
# Check status
systemctl --user status teams-status-client

# View logs
journalctl --user -u teams-status-client -f

# Stop the service
systemctl --user stop teams-status-client

# Disable auto-start
systemctl --user disable teams-status-client
```

## Troubleshooting

### Teams logs not found

If the client reports "Unknown" status, Teams may be installed in a non-standard location. Run with `--verbose` to see which paths are being checked.

### Permission issues

Ensure you have read access to the Teams log files:

```bash
ls -la ~/.config/Microsoft/Microsoft\ Teams/
```

### Terminal display issues

The client uses ANSI escape codes for the UI. If the display looks wrong, ensure your terminal emulator supports ANSI colors (most modern terminals do).
