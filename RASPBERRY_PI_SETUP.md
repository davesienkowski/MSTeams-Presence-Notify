# Raspberry Pi 3 Model B+ with Unicorn HAT Setup Guide

Complete setup guide for displaying Microsoft Teams presence status on a Raspberry Pi 3 Model B+ with Pimoroni Unicorn HAT (8x8 WS2812B RGB LED matrix).

## Table of Contents
1. [Hardware Requirements](#hardware-requirements)
2. [Hardware Assembly](#hardware-assembly)
3. [Software Installation](#software-installation)
4. [Configuration](#configuration)
5. [Running the Application](#running-the-application)
6. [Customization](#customization)
7. [Troubleshooting](#troubleshooting)

---

## Hardware Requirements

### Required Hardware
- **Raspberry Pi 3 Model B+** (also works with Pi 2, Pi 4, Pi Zero W)
- **Pimoroni Unicorn HAT** (8x8 WS2812B RGB LED matrix)
  - Product: [Unicorn HAT](https://shop.pimoroni.com/products/unicorn-hat)
  - 64 individually addressable RGB LEDs
  - Mounts directly on 40-pin GPIO header
- **Power Supply**: 5V 2.5A+ micro USB (recommended 3A for Pi + LEDs)
- **MicroSD Card**: 8GB+ with Raspberry Pi OS installed
- **Network Connection**: WiFi or Ethernet

### Optional Hardware
- **Case**: Must accommodate HAT height (~10mm above GPIO pins)
- **Heatsinks**: Recommended if running continuously
- **Diffuser**: Translucent acrylic sheet to soften LED glare

---

## Hardware Assembly

### Step 1: Prepare Raspberry Pi
1. Install Raspberry Pi OS (Lite or Desktop) on microSD card
   - Download from: https://www.raspberrypi.com/software/
   - Use Raspberry Pi Imager for easy setup
2. Insert microSD card into Pi
3. Connect keyboard, mouse, and monitor (if using Desktop version)

### Step 2: Mount Unicorn HAT
1. **Power off** Raspberry Pi completely
2. Align Unicorn HAT with 40-pin GPIO header
3. Press down firmly until fully seated
4. Ensure all pins are connected (LEDs face up)

⚠️ **IMPORTANT**: Never connect or disconnect the HAT while Pi is powered on!

### Step 3: Power Considerations
The Unicorn HAT draws significant current when all LEDs are at full brightness:
- **Full white (all 64 LEDs)**: ~3.8A @ 5V
- **Typical usage**: ~1-2A with animations

**Power Supply Recommendations**:
- Minimum: 2.5A official Raspberry Pi power supply
- Recommended: 3A+ power supply
- For bright white displays: 5A power supply

**Optional External Power** (advanced):
If experiencing power issues or undervoltage warnings:
1. Solder 5V power wire to HAT's 5V pad
2. Connect to separate 5A 5V power supply
3. Share common ground with Raspberry Pi

---

## Software Installation

### Step 1: Update System
```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### Step 2: Install Unicorn HAT Library

**Option A: One-Line Installer (Recommended)**
```bash
curl -sS https://get.pimoroni.com/unicornhat | bash
```
This installs:
- Python libraries for Unicorn HAT
- Required system dependencies
- Example code (optional)

**Option B: Manual Installation**
```bash
# Install Python 3 and pip
sudo apt-get install python3-pip python3-dev -y

# Install Unicorn HAT library
sudo pip3 install unicornhat

# Install additional dependencies
sudo apt-get install python3-requests -y
```

### Step 3: Fix Audio Conflicts (Optional)
The Unicorn HAT uses PWM on GPIO 18, which conflicts with analog audio.
If you see flickering or random patterns:

```bash
sudo nano /boot/config.txt
```

Add this line:
```
hdmi_force_hotplug=1
```

Save (Ctrl+O, Enter) and reboot:
```bash
sudo reboot
```

### Step 4: Download Teams Status Application

**Option A: Clone Repository**
```bash
cd ~
git clone https://github.com/YOUR_USERNAME/MSTeams-Presence-Notify.git
cd MSTeams-Presence-Notify/raspberry_pi_unicorn
```

**Option B: Download Files Directly**
```bash
mkdir -p ~/teams-unicorn
cd ~/teams-unicorn
wget https://raw.githubusercontent.com/YOUR_USERNAME/MSTeams-Presence-Notify/main/raspberry_pi_unicorn/teams_status_unicorn.py
wget https://raw.githubusercontent.com/YOUR_USERNAME/MSTeams-Presence-Notify/main/raspberry_pi_unicorn/requirements.txt
```

### Step 5: Install Python Dependencies
```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
pip3 install -r requirements.txt
```

---

## Configuration

### Step 1: Start PowerShell Server on Windows PC

On your Windows PC with Microsoft Teams:

```powershell
cd powershell_service
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1
```

The server will start on port 8080. Note your PC's IP address.

### Step 2: Add Firewall Rule (Windows PC)

Run as Administrator:
```powershell
New-NetFirewallRule -DisplayName "Teams Status Server" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow -Profile Private
```

### Step 3: Find Your PC's IP Address

**Windows:**
```powershell
ipconfig
```
Look for "IPv4 Address" (e.g., 192.168.1.100)

### Step 4: Configure Raspberry Pi Script

Edit the Python script:
```bash
nano ~/MSTeams-Presence-Notify/raspberry_pi_unicorn/teams_status_unicorn.py
```

Change line 16:
```python
SERVER_URL = "http://192.168.1.100:8080/status"  # Use your PC's IP
```

**Optional Configuration** (lines 17-21):
```python
POLL_INTERVAL = 5        # Seconds between checks (default: 5)
BRIGHTNESS = 0.5         # LED brightness 0.0-1.0 (default: 0.5)
ANIMATION_MODE = "pulse" # Animation style (see options below)
```

Save (Ctrl+O, Enter) and exit (Ctrl+X).

---

## Running the Application

### Test Run
```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
sudo python3 teams_status_unicorn.py
```

**Expected Output:**
```
==================================================
MS Teams Presence - Raspberry Pi Unicorn HAT
==================================================
Server URL: http://192.168.1.100:8080/status
Poll interval: 5 seconds
Animation mode: pulse
Brightness: 50%

Press Ctrl+C to exit

Unicorn HAT initialized: 8x8 matrix at 50% brightness
Running startup animation...
Status changed: None → Available
```

The Unicorn HAT should display:
1. Rainbow startup animation
2. Your current Teams status color
3. Animated effect based on `ANIMATION_MODE`

### Stop Application
Press **Ctrl+C** for graceful shutdown.

### Run at Startup (systemd service)

Create service file:
```bash
sudo nano /etc/systemd/system/teams-unicorn.service
```

Add this content (adjust paths if needed):
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

Enable and start service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable teams-unicorn.service
sudo systemctl start teams-unicorn.service
```

**Service Management Commands:**
```bash
sudo systemctl status teams-unicorn  # Check status
sudo systemctl stop teams-unicorn    # Stop service
sudo systemctl restart teams-unicorn # Restart service
sudo journalctl -u teams-unicorn -f  # View logs
```

---

## Customization

### Animation Modes

Edit `ANIMATION_MODE` in `teams_status_unicorn.py` (line 21):

| Mode | Description | Effect |
|------|-------------|--------|
| `solid` | Static color | No animation, single solid color |
| `pulse` | Breathing effect | Smooth fade in/out (default) |
| `gradient` | Vertical fade | Color fades from top to bottom |
| `ripple` | Wave from center | Expanding ripple effect |
| `spinner` | Rotating line | Spinning line animation |

**Example:**
```python
ANIMATION_MODE = "ripple"
```

### Brightness Adjustment

Adjust `BRIGHTNESS` (line 20):
```python
BRIGHTNESS = 0.3  # 30% brightness (easier on eyes)
BRIGHTNESS = 1.0  # 100% brightness (maximum)
```

⚠️ **Warning**: Full brightness draws 3.8A. Ensure adequate power supply!

### Rotation

If HAT is mounted rotated, change line 41:
```python
unicorn.rotation(90)  # 0, 90, 180, or 270 degrees
```

### Status Colors

Customize colors in `STATUS_COLORS` dictionary (lines 24-34):
```python
STATUS_COLORS = {
    "Available": (0, 255, 0),      # Green (RGB)
    "Busy": (255, 0, 0),            # Red
    # Modify RGB values to taste
}
```

RGB values range from 0-255 for each color channel.

### Poll Interval

Change check frequency (line 19):
```python
POLL_INTERVAL = 10  # Check every 10 seconds (reduces network traffic)
POLL_INTERVAL = 2   # Check every 2 seconds (more responsive)
```

---

## Troubleshooting

### LEDs Don't Light Up

**Check Power:**
```bash
vcgencmd get_throttled
```
- `0x0`: Power is good
- `0x50005`: Undervoltage detected (upgrade power supply)

**Check HAT Connection:**
```bash
sudo python3 -c "import unicornhat; unicornhat.set_pixel(0,0,255,0,0); unicornhat.show()"
```
Top-left LED should turn red. If not, reseat HAT.

**Check Permissions:**
The script requires `sudo` to access GPIO. Run as root or add user to gpio group:
```bash
sudo usermod -a -G gpio pi
```

### Random Flickering or Patterns

**Audio Conflict:**
Add to `/boot/config.txt`:
```
hdmi_force_hotplug=1
# Optionally disable onboard audio completely:
dtparam=audio=off
```

**Insufficient Power:**
Upgrade to 3A+ power supply or reduce brightness.

### Connection Errors

**Check Server Accessibility:**
```bash
curl http://192.168.1.100:8080/status
```

Expected response:
```json
{"availability":"Available","activity":"Available","color":"#00FF00"}
```

**Common Issues:**
- Wrong IP address in configuration
- Firewall blocking port 8080 on Windows PC
- PowerShell server not running
- PC and Pi on different networks

**Test from Pi:**
```bash
ping 192.168.1.100  # Should get responses
```

### Status Not Updating

**Check Logs:**
```bash
sudo journalctl -u teams-unicorn -f
```

Look for:
- Connection errors
- HTTP timeouts
- Permission issues

**Manual Test:**
```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
sudo python3 teams_status_unicorn.py
```

### High CPU Usage

Animations can be CPU-intensive. Optimize:
```python
ANIMATION_MODE = "solid"  # No animation, lowest CPU
POLL_INTERVAL = 10        # Reduce polling frequency
```

### HAT Gets Hot

Normal during operation. Add heatsinks to Raspberry Pi if concerned.

---

## Advanced Configuration

### Custom Animations

Add your own animations in `teams_status_unicorn.py`:

```python
def my_custom_animation(color):
    """Your custom animation"""
    r, g, b = color
    # Your animation code here
    for frame in range(20):
        # Set pixels
        unicorn.show()
        time.sleep(0.05)
```

Then set:
```python
ANIMATION_MODE = "my_custom"
```

### Remote Access

Access Pi remotely via SSH:
```bash
ssh pi@raspberrypi.local
```

Enable SSH via `sudo raspi-config` → Interface Options → SSH.

### Multiple Status Sources

Modify `get_teams_status()` to support multiple servers or fallback sources.

---

## Status Color Reference

| Teams Status | Color | RGB Values |
|-------------|-------|------------|
| Available | Green | (0, 255, 0) |
| Busy | Red | (255, 0, 0) |
| Away | Yellow | (255, 255, 0) |
| Be Right Back | Yellow | (255, 255, 0) |
| Do Not Disturb | Purple | (128, 0, 128) |
| In a Meeting | Red | (255, 0, 0) |
| In a Call | Red | (255, 0, 0) |
| Offline | Gray | (128, 128, 128) |
| Unknown | White | (255, 255, 255) |

---

## Support & Resources

**Official Documentation:**
- [Pimoroni Unicorn HAT](https://learn.pimoroni.com/getting-started-with-unicorn-hat)
- [Raspberry Pi GPIO](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html)

**Troubleshooting:**
- Open issue on GitHub repository
- Check firewall settings on Windows PC
- Verify network connectivity between Pi and PC

**Community:**
- [Pimoroni Forums](https://forums.pimoroni.com/)
- [Raspberry Pi Forums](https://forums.raspberrypi.com/)

---

## Performance Tips

1. **Reduce Brightness**: Lowers power consumption and heat
2. **Solid Animation**: Lowest CPU usage
3. **Increase Poll Interval**: Reduces network traffic
4. **Disable HDMI**: If running headless (`/usr/bin/tvservice -o`)
5. **Overclock**: Improves animation smoothness (use with caution)

---

## Safety Notes

⚠️ **LED Warning**: WS2812B LEDs are extremely bright. Avoid staring directly at full brightness.

⚠️ **Power Warning**: Ensure adequate power supply to prevent SD card corruption.

⚠️ **Heat Warning**: LEDs and Pi generate heat. Ensure adequate ventilation.

---

## License

MIT License - See main repository LICENSE file.

## Credits

- Teams log parsing technique: [EBOOZ/TeamsStatus](https://github.com/EBOOZ/TeamsStatus)
- Unicorn HAT library: [Pimoroni](https://github.com/pimoroni/unicorn-hat)
