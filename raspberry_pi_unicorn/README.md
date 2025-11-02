# Raspberry Pi + Unicorn HAT - Teams Status Display

Display your Microsoft Teams presence status on an 8x8 RGB LED matrix (Pimoroni Unicorn HAT).

## Hardware
- **Raspberry Pi 3 Model B+** (also works with Pi 2, Pi 4, Pi Zero W)
- **Pimoroni Unicorn HAT** - 8x8 WS2812B RGB LED matrix
- **Power Supply** - 5V 2.5A+ recommended (3A for full brightness)

## Quick Start

### 1. Install Unicorn HAT Library
```bash
curl -sS https://get.pimoroni.com/unicornhat | bash
```

### 2. Install Dependencies
```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
pip3 install -r requirements.txt
```

### 3. Start PowerShell Server on Windows PC
```powershell
cd powershell_service
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1
```

### 4. Configure Server URL
Edit `teams_status_unicorn.py` and change line 16:
```python
SERVER_URL = "http://YOUR_PC_IP:8080/status"  # Use your PC's IP address
```

### 5. Run Application
```bash
sudo python3 teams_status_unicorn.py
```

You should see:
1. Rainbow startup animation
2. LED matrix displaying your Teams status color
3. Animated effects (default: pulse)

## Features

### Status Colors
- 🟢 **Green** - Available
- 🔴 **Red** - Busy / In Meeting / In Call
- 🟡 **Yellow** - Away / Be Right Back
- 🟣 **Purple** - Do Not Disturb
- ⚪ **Gray** - Offline
- ⚫ **White** - Unknown

### Animation Modes
Change `ANIMATION_MODE` in the script (line 21):

| Mode | Description |
|------|-------------|
| `solid` | Static color, no animation |
| `pulse` | Breathing effect (default) |
| `gradient` | Vertical color fade |
| `ripple` | Expanding wave from center |
| `spinner` | Rotating line effect |

### Customization Options

**Brightness** (line 20):
```python
BRIGHTNESS = 0.5  # Range: 0.0 to 1.0
```

**Poll Interval** (line 19):
```python
POLL_INTERVAL = 5  # Seconds between status checks
```

**Rotation** (line 41):
```python
unicorn.rotation(90)  # 0, 90, 180, or 270 degrees
```

## Auto-Start on Boot

Create systemd service:
```bash
sudo nano /etc/systemd/system/teams-unicorn.service
```

Add:
```ini
[Unit]
Description=MS Teams Status Unicorn HAT Display
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn
ExecStart=/usr/bin/python3 /home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn/teams_status_unicorn.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable teams-unicorn.service
sudo systemctl start teams-unicorn.service
```

## Troubleshooting

### LEDs Don't Light Up
```bash
# Check power status
vcgencmd get_throttled  # Should return 0x0

# Test HAT directly
sudo python3 -c "import unicornhat; unicornhat.set_pixel(0,0,255,0,0); unicornhat.show()"
```

### Connection Errors
```bash
# Test server connectivity
curl http://YOUR_PC_IP:8080/status

# Check network
ping YOUR_PC_IP
```

### Flickering / Random Patterns
Edit `/boot/config.txt`:
```bash
sudo nano /boot/config.txt
```

Add:
```
hdmi_force_hotplug=1
```

Reboot:
```bash
sudo reboot
```

### Check Logs
```bash
# If running as service
sudo journalctl -u teams-unicorn -f

# If running manually
sudo python3 teams_status_unicorn.py
```

## Complete Documentation

See [RASPBERRY_PI_SETUP.md](../RASPBERRY_PI_SETUP.md) for:
- Detailed hardware assembly instructions
- Power supply recommendations
- Advanced customization
- Custom animation creation
- Remote access setup
- Performance optimization

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  MS Teams App   │────▶│  PowerShell      │────▶│  Raspberry Pi   │
│  (Windows PC)   │     │  HTTP Server     │     │  + Unicorn HAT  │
│  Log Monitoring │     │  (Port 8080)     │     │  8x8 LED Matrix │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                              WiFi/Ethernet
```

## Resources

- [Complete Setup Guide](../RASPBERRY_PI_SETUP.md)
- [Main Project README](../README.md)
- [Pimoroni Unicorn HAT](https://shop.pimoroni.com/products/unicorn-hat)
- [Unicorn HAT Python Library](https://github.com/pimoroni/unicorn-hat)

## License

MIT License - See [LICENSE](../LICENSE) file.
