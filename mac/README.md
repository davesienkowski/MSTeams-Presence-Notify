# MS Teams Status Push Client for macOS

Monitors Microsoft Teams logs and pushes status updates to a Raspberry Pi server.

## Prerequisites

- Python 3.6+
- `requests` library

## Installation

```bash
# Install the requests library
pip3 install requests
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

- **New Teams**: `~/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams/Logs`
- **Classic Teams**: `~/Library/Application Support/Microsoft/Teams/Logs`

## Running at Startup

To run the client automatically at login:

1. Create a Launch Agent plist file:

```bash
cat > ~/Library/LaunchAgents/com.teams.statusclient.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.teams.statusclient</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>/path/to/TeamsPushClient.py</string>
        <string>--ip</string>
        <string>192.168.50.137</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
```

2. Load the Launch Agent:

```bash
launchctl load ~/Library/LaunchAgents/com.teams.statusclient.plist
```

3. To stop:

```bash
launchctl unload ~/Library/LaunchAgents/com.teams.statusclient.plist
```
