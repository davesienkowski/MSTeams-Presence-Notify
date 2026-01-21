# MS Teams Presence Notification Light

Display your Microsoft Teams status on a Raspberry Pi with Unicorn HAT (8x8 RGB LED matrix). Uses a push architecture where your Windows PC monitors Teams logs and pushes status updates to the Raspberry Pi.

## Architecture

```
Windows PC                          Raspberry Pi
[MS Teams] --> [TeamsPushClient.ps1] --> HTTP POST --> [teams_status_integrated_push.py] --> [Unicorn HAT LEDs]
                     |                                              |
               Monitors Teams logs                          Receives status updates
               Pushes to Pi on change                       Controls 8x8 LED matrix
                                                            Optional: Web dashboard, notifications, Home Assistant
```

**Key Benefits:**
- No Microsoft Graph API required
- No Azure AD setup
- No admin permissions needed
- Works on restricted corporate networks

## Status Colors

| Status | Color | LED Display |
|--------|-------|-------------|
| Available | Green | Solid/animated green |
| Busy | Red | Solid/animated red |
| Away | Yellow | Solid/animated yellow |
| BeRightBack | Yellow | Solid/animated yellow |
| DoNotDisturb | Purple | Solid/animated purple |
| InAMeeting | Red | Solid/animated red |
| InACall | Red | Solid/animated red |
| Offline | Gray | Solid/animated gray |
| Unknown | White | Solid/animated white |

## Hardware Requirements

### Raspberry Pi
- Raspberry Pi 3 Model B+ (or Pi 2/4/Zero W)
- [Pimoroni Unicorn HAT](https://shop.pimoroni.com/products/unicorn-hat) (8x8 WS2812B RGB LEDs)
- 5V 2.5A+ power supply
- MicroSD card with Raspberry Pi OS

### Windows PC
- Microsoft Teams (New Teams or Classic)
- PowerShell 5.1+ (built into Windows)
- Network access to Raspberry Pi

## Quick Start

### 1. Raspberry Pi Setup

**Install dependencies:**
```bash
# Install Unicorn HAT library
curl -sS https://get.pimoroni.com/unicornhat | bash

# Clone this repo
git clone https://github.com/yourusername/MSTeams-Presence-Notify.git
cd MSTeams-Presence-Notify/raspberry_pi_unicorn

# Install Python dependencies
pip3 install -r requirements_integrated.txt
```

**Configure the server:**
```bash
# Copy the example config
cp config_push.yaml.example config_push.yaml

# Edit with your settings
nano config_push.yaml
```

**Configuration options (`config_push.yaml`):**
```yaml
server:
  port: 8080              # Port for receiving status from Windows PC

unicorn:
  brightness: 0.5         # LED brightness (0.0 to 1.0)
  animation_mode: "pulse" # solid, pulse, gradient, ripple, spinner

web:
  enabled: true           # Enable web dashboard
  host: "0.0.0.0"
  port: 5000              # Dashboard at http://<pi-ip>:5000

notifications:
  enabled: false          # Push notifications via ntfy.sh
  ntfy_topic: "my-unique-topic"

homeassistant:
  enabled: false          # MQTT integration for Home Assistant
```

**Start the server:**
```bash
sudo python3 teams_status_integrated_push.py
```

**Optional: Auto-start on boot:**
```bash
# Add to /etc/rc.local before 'exit 0'
sudo nano /etc/rc.local
# Add: cd /home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn && sudo python3 teams_status_integrated_push.py &
```

### 2. Windows PC Setup

**Run the PowerShell client:**
```powershell
cd powershell_service

# Run with default settings (edit the script to change IP)
powershell -ExecutionPolicy Bypass -File TeamsPushClient.ps1

# Or specify parameters
powershell -ExecutionPolicy Bypass -File TeamsPushClient.ps1 -RaspberryPiIP "192.168.1.100" -Port 8080 -PollInterval 5
```

**Parameters:**
- `-RaspberryPiIP`: IP address of your Raspberry Pi (default: 192.168.50.137)
- `-Port`: Port number (default: 8080)
- `-PollInterval`: Seconds between status checks (default: 5)

**Optional: Create a shortcut:**
1. Create a `.bat` file:
```batch
@echo off
powershell -ExecutionPolicy Bypass -File "C:\path\to\TeamsPushClient.ps1" -RaspberryPiIP "192.168.1.100"
```
2. Add to Startup folder for auto-launch

## Project Structure

```
MSTeams-Presence-Notify/
├── powershell_service/
│   └── TeamsPushClient.ps1      # Windows client - monitors Teams & pushes status
├── raspberry_pi_unicorn/
│   ├── teams_status_integrated_push.py  # Pi server - receives status & controls LEDs
│   ├── config_push.yaml.example         # Example configuration
│   └── requirements_integrated.txt      # Python dependencies
└── README.md
```

## Features

### Unicorn HAT Display
- 8x8 RGB LED matrix (64 individually addressable LEDs)
- Multiple animation modes: solid, pulse, gradient, ripple, spinner
- Adjustable brightness

### Web Dashboard (Optional)
- Mobile-friendly status display
- Access at `http://<pi-ip>:5000`
- Real-time status updates

### Push Notifications (Optional)
- Uses [ntfy.sh](https://ntfy.sh) for free push notifications
- Receive status change alerts on your phone
- Subscribe to your topic in the ntfy app

### Home Assistant (Optional)
- MQTT integration for smart home automation
- Create automations based on your Teams status

## Troubleshooting

### PowerShell Client
- **Teams log not found**: Ensure Teams is running. The client checks both New Teams and Classic Teams log locations.
- **Cannot connect to Pi**: Check firewall settings, ensure Pi is on the same network.
- **Status always "Unknown"**: Run with `-Verbose` to see debug output and matched patterns.

### Raspberry Pi
- **LEDs not lighting**: Ensure Unicorn HAT is properly seated on GPIO. Run with `sudo`.
- **Web dashboard not accessible**: Check firewall, ensure port 5000 is open.
- **Permission denied**: The script requires sudo to access GPIO.

### Network
- **Connection refused**: Verify Pi IP address and port 8080 is open.
- **No status updates**: Check that both devices are on the same network segment.

## How It Works

1. **Teams writes status to local log files** - Teams continuously updates log files with presence information
2. **PowerShell monitors logs** - The client reads the last 5000 lines of the newest Teams log every 5 seconds
3. **Status parsed via regex** - Looks for patterns like `availability: Available`, `SetBadge status`, etc.
4. **HTTP POST to Raspberry Pi** - When status changes, sends JSON: `{"availability":"Busy","activity":"Busy","color":"#FF0000"}`
5. **Pi updates LED display** - Changes the Unicorn HAT color and animation based on received status

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions welcome! Please open an issue or submit a pull request.
