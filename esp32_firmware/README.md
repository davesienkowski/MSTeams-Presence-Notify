# ESP32 WiFi Implementation - Setup Guide

Complete guide for setting up Teams Status monitoring with ESP32 via WiFi.

## Why WiFi over BLE?

✅ **Better Range**: 30-50m (100-150ft) vs 10m (30ft) BLE
✅ **More Reliable**: Rock-solid TCP/IP stack, no Windows BLE quirks
✅ **Less Interference**: Better handling of 2.4GHz interference
✅ **Simpler Code**: ~100 lines (vs 270 for BLE), HTTP is battle-tested
✅ **Network Discovery**: mDNS lets you use `teams-status.local` instead of IP

## Hardware Requirements

### Option 1: ESP32 DevKit (Recommended - $8-12)
- Any ESP32 development board with WiFi
- Common variants: ESP32-WROOM, ESP32-WROVER, NodeMCU-32S
- USB-C or Micro-USB for power and programming

### Option 2: Reuse Your RFduino Shield
If you have the RGB Shield from the BLE setup, you can reuse it:
- ESP32 board compatible with shield pinout
- RFD22122 RGB Shield (or equivalent)
- Verify pin connections match

### RGB LED Components (if building from scratch)
- **Common Cathode RGB LED** (one with 4 pins)
- **3x 220Ω resistors** (one for each color channel)
- **Breadboard** (optional, for prototyping)

## Wiring Diagram

### Standard RGB LED Connection
```
ESP32 Pin     Component         LED Pin
-----------------------------------------
GPIO 25   ──[220Ω]──> Red Anode     (R)
GPIO 26   ──[220Ω]──> Green Anode   (G)
GPIO 27   ──[220Ω]──> Blue Anode    (B)
GND       ─────────> Common Cathode (-)
```

**Note**: If you have a **common anode** LED, connect the common pin to 3.3V and invert the PWM values in the code.

### Pin Configuration
The firmware uses these GPIO pins (you can change them in the code):
- `GPIO 25` - Red LED channel
- `GPIO 26` - Green LED channel
- `GPIO 27` - Blue LED channel

**Important**: Make sure your pins support PWM (most ESP32 GPIOs do).

## Software Setup

### Step 1: Install Arduino IDE

1. Download Arduino IDE 1.8.x or 2.x from [arduino.cc](https://www.arduino.cc/en/software)
2. Install and launch Arduino IDE

### Step 2: Add ESP32 Board Support

1. Open **File → Preferences**
2. In "Additional Board Manager URLs", add:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
3. Click **OK**
4. Go to **Tools → Board → Boards Manager**
5. Search for "esp32"
6. Install "**esp32 by Espressif Systems**" (latest version)
7. Wait for installation to complete

### Step 3: Configure WiFi Credentials

1. Open `TeamsStatus_WiFi.ino` in Arduino IDE
2. Find these lines near the top (around line 25):
   ```cpp
   const char* WIFI_SSID = "YOUR_WIFI_SSID";
   const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
   ```
3. Replace with your **work WiFi** credentials:
   ```cpp
   const char* WIFI_SSID = "CompanyWiFi-5G";
   const char* WIFI_PASSWORD = "your-password-here";
   ```

**Security Note**: This stores WiFi credentials in the firmware. If concerned:
- Use a guest network
- Create a dedicated IoT SSID
- Use WPA2-Enterprise if your workplace supports device certificates

### Step 4: Upload Firmware

1. Connect ESP32 to your computer via USB
2. In Arduino IDE, select:
   - **Tools → Board → ESP32 Arduino → ESP32 Dev Module** (or your specific board)
   - **Tools → Port → COM# (your ESP32)**
3. Click **Upload** button (→)
4. Wait for compilation and upload

### Step 5: Verify Connection

1. Open **Tools → Serial Monitor** (Ctrl+Shift+M)
2. Set baud rate to **115200**
3. Press **RESET** button on ESP32
4. You should see:
   ```
   ========================================
   Teams Status ESP32 WiFi Monitor
   ========================================

   Connecting to WiFi: YourSSID
   ......
   [OK] WiFi connected!
   IP Address: 192.168.1.123
   Signal Strength: -45 dBm
   mDNS responder started: http://teams-status.local
   [OK] HTTP server started on port 80

   Ready to receive Teams status updates!
   ========================================
   ```

5. **Write down the IP address** - you'll need it for the PC software!

### Step 6: Test Web Interface

1. Open a web browser (on any device on the same network)
2. Go to: `http://teams-status.local` or `http://[IP-ADDRESS]`
3. You should see the Teams Status Monitor web page
4. LED preview should show white (unknown status)

## PC Software Setup

### Option A: Download Pre-built Executable (Easiest)

1. Download `TeamsWiFiTransmitter.exe` from the releases
2. Place it in a convenient folder
3. Open Command Prompt or PowerShell in that folder
4. Run:
   ```cmd
   TeamsWiFiTransmitter.exe http://teams-status.local
   ```
   Or use IP address:
   ```cmd
   TeamsWiFiTransmitter.exe http://192.168.1.123
   ```

### Option B: Build from Source

1. Make sure you have **.NET 8.0 SDK** installed
   - Download from: [dotnet.microsoft.com](https://dotnet.microsoft.com/download)
2. Open PowerShell in the `dotnet_wifi_service` folder
3. Run the build script:
   ```powershell
   .\Build.ps1
   ```
4. Executable will be created at: `bin\Release\...\TeamsWiFiTransmitter.exe`

### Running the Transmitter

**Method 1: Command Line**
```powershell
# Using mDNS (recommended)
TeamsWiFiTransmitter.exe http://teams-status.local

# Using IP address (if mDNS doesn't work)
TeamsWiFiTransmitter.exe http://192.168.1.123
```

**Method 2: Create a Shortcut**
1. Right-click `TeamsWiFiTransmitter.exe` → Create Shortcut
2. Right-click shortcut → Properties
3. In "Target", add the ESP32 address:
   ```
   C:\Path\To\TeamsWiFiTransmitter.exe http://teams-status.local
   ```
4. Click **OK**
5. Double-click shortcut to start

**Method 3: Run at Startup**
1. Press `Win+R`, type `shell:startup`, press Enter
2. Copy the shortcut from Method 2 into this folder
3. It will now start automatically when you log in

## Troubleshooting

### ESP32 Won't Connect to WiFi

**Symptoms**: LED blinks red continuously, Serial Monitor shows "WiFi connection failed"

**Solutions**:
1. ✅ Double-check SSID and password in the code
2. ✅ Make sure you're using 2.4GHz WiFi (ESP32 doesn't support 5GHz)
3. ✅ Verify WiFi network allows device connections (not guest-only)
4. ✅ Try moving ESP32 closer to the router
5. ✅ Check if MAC address filtering is enabled on router

### PC Can't Find ESP32 (mDNS Issues)

**Symptoms**: `teams-status.local` doesn't work, connection timeout

**Solutions**:
1. ✅ Use the IP address directly instead:
   ```cmd
   TeamsWiFiTransmitter.exe http://192.168.1.123
   ```
2. ✅ Check Serial Monitor for the IP address
3. ✅ Make sure both PC and ESP32 are on the same network
4. ✅ Disable VPN if running on PC
5. ✅ Windows Firewall might block mDNS - allow "Bonjour Service"

### LED Doesn't Change Color

**Symptoms**: ESP32 connects, but LED stays white or doesn't update

**Solutions**:
1. ✅ Verify PC transmitter is running and connected
2. ✅ Check Serial Monitor for "Status updated: X" messages
3. ✅ Test the web interface - does it show status updates?
4. ✅ Verify LED wiring (common cathode vs common anode)
5. ✅ Check if resistor values are correct (220Ω)

### Teams Status Not Detected

**Symptoms**: Transmitter runs but always shows "Unknown"

**Solutions**:
1. ✅ Make sure Microsoft Teams is running
2. ✅ Change your status in Teams manually to test
3. ✅ Check that Teams is writing logs:
   - New Teams: `%AppData%\Microsoft\Teams\logs.txt`
   - Classic Teams: `%AppData%\Microsoft\Teams\logs\MSTeams.log`
4. ✅ Restart Teams and the transmitter

### Firewall Issues

**Symptoms**: Connection refused, timeout errors

**Solutions**:
1. ✅ Windows Firewall may block the connection
2. ✅ Add firewall rule (run as Administrator):
   ```powershell
   New-NetFirewallRule -DisplayName "Teams ESP32" -Direction Outbound -LocalPort 80 -Protocol TCP -Action Allow
   ```
3. ✅ Check corporate firewall settings

## LED Status Indicators

### During Boot
- **White Pulse**: Starting up / Connecting to WiFi
- **3x Green Blink**: Ready and waiting for status
- **Red Blink Loop**: WiFi connection failed

### During Operation
| Color | Teams Status |
|-------|-------------|
| 🟢 Green | Available |
| 🔴 Red | Busy / In Meeting / In Call / Presenting |
| 🟡 Yellow | Away / Be Right Back |
| 🟣 Purple | Do Not Disturb / Focusing |
| ⚫ Dim Gray | Offline |
| ⚪ White | Unknown |

## Network Protocol Details

The ESP32 exposes a simple HTTP API:

### POST /status
Update Teams status
```http
POST /status HTTP/1.1
Content-Type: application/json

{"status": 0}
```

Status codes: 0-10 (see TeamsStatus enum)

**Response**: `{"success":true}`

### GET /
Web interface for monitoring

### GET /api/current
Get current status
```json
{
  "status": 0,
  "timestamp": 1234567890
}
```

### GET /api/health
Health check endpoint
```json
{
  "status": "healthy",
  "uptime": 3600,
  "wifi_rssi": -45
}
```

## Advanced Configuration

### Changing LED Pins

Edit these lines in `TeamsStatus_WiFi.ino`:
```cpp
const int RED_PIN = 25;    // Your red pin
const int GREEN_PIN = 26;  // Your green pin
const int BLUE_PIN = 27;   // Your blue pin
```

### Changing WiFi Settings

```cpp
// Change HTTP port (default: 80)
const int HTTP_PORT = 8080;

// Change mDNS hostname (default: teams-status.local)
const char* MDNS_HOSTNAME = "my-teams-light";
```

### Using Static IP

Add before `WiFi.begin()`:
```cpp
IPAddress staticIP(192, 168, 1, 100);
IPAddress gateway(192, 168, 1, 1);
IPAddress subnet(255, 255, 255, 0);
WiFi.config(staticIP, gateway, subnet);
```

## Security Considerations

### Network Security
- ✅ **Use WPA2/WPA3**: Don't connect to open/WEP networks
- ✅ **Guest Network**: Consider using a separate guest/IoT network
- ✅ **MAC Filtering**: Add ESP32 MAC to allowed devices
- ✅ **Network Segmentation**: Keep IoT devices on isolated VLAN

### Code Security
- ⚠️ **Credentials in Firmware**: WiFi password is stored in flash
- ✅ **HTTPS**: Could add TLS for encrypted communication (advanced)
- ✅ **Authentication**: Could add API key for POST requests (advanced)

## Performance & Reliability

### WiFi vs BLE Comparison

| Feature | WiFi (ESP32) | BLE (RFduino) |
|---------|--------------|---------------|
| **Range** | 30-50m | 10m |
| **Reliability** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Setup Complexity** | Medium | Hard |
| **Code Complexity** | Simple | Complex |
| **Stack Reliability** | Excellent | Windows issues |
| **Power Consumption** | Higher (USB) | Lower (battery) |
| **Firewall Issues** | None | None |

### Power Consumption

**ESP32 WiFi Mode**:
- Active: ~150-240mA
- Sleep: ~10mA (not implemented in this version)

**Power Supply**:
- USB power required (~5V 500mA)
- Not suitable for battery operation in current implementation
- For battery operation, implement deep sleep mode (advanced)

## Maintenance

### Updating Firmware
1. Connect ESP32 via USB
2. Upload new firmware via Arduino IDE
3. LED will blink during upload
4. Device will reboot automatically

### Logs and Debugging
- Serial Monitor shows all connection and status events
- Web interface shows current status and connection info
- Check `/api/health` endpoint for uptime and signal strength

## Next Steps

### Enhancements
- 🔧 Add HTTPS support for encrypted communication
- 🔧 Implement deep sleep mode for battery operation
- 🔧 Add physical button for manual status override
- 🔧 Display on OLED/LCD screen
- 🔧 RGB strip support for bigger displays
- 🔧 Multiple device support (broadcast to several ESP32s)

### Integration Ideas
- 📱 Control via smartphone app
- 🏠 Home Assistant integration
- 🔔 Desktop notifications when status changes
- 📊 Status time tracking and analytics

## Support

For issues and questions:
- Check [Troubleshooting](#troubleshooting) section
- Open a GitHub issue
- Check ESP32 forums and documentation

## License

MIT License - See main project LICENSE file

---

**Congratulations!** You now have a reliable WiFi-based Teams presence indicator! 🎉
