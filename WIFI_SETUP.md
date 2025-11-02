# WiFi Implementation - Complete Overview

This guide covers the **ESP32 WiFi implementation** as an alternative to BLE (RFduino).

## Why Choose WiFi?

### Advantages ✅
1. **Better Range**: 30-50m (100-150ft) vs 10m (30ft) for BLE
2. **Higher Reliability**: Rock-solid TCP/IP stack, no Windows BLE quirks
3. **Simpler Code**: ~100 lines firmware vs 270 for BLE
4. **Network Discovery**: mDNS support (`teams-status.local`)
5. **Web Interface**: Built-in status page and monitoring

### Trade-offs ⚠️
1. **Requires WiFi**: Must have network access (BLE doesn't need network)
2. **Power Consumption**: Higher than BLE (needs USB power)
3. **Network Security**: WiFi credentials stored in firmware

## Architecture

```
┌──────────────────┐         WiFi (mDNS)        ┌───────────────┐
│   Work PC        │  ←─────────────────────→   │    ESP32      │
│ Teams WiFi       │   HTTP POST /status        │  Web Server   │
│ Transmitter.exe  │   {"status": 0}            │  :80          │
└──────────────────┘                             └───────┬───────┘
                                                         │
                                                  ┌──────┴───────┐
                                                  │   RGB LED    │
                                                  │  (PWM pins)  │
                                                  └──────────────┘
```

## File Structure

```
MSTeams-Presence-Notify/
├── esp32_firmware/
│   ├── TeamsStatus_WiFi/
│   │   └── TeamsStatus_WiFi.ino       # ESP32 Arduino firmware
│   ├── README.md                       # Detailed setup guide
│   └── QUICKSTART.md                   # 5-minute setup
│
└── dotnet_wifi_service/
    ├── Program.cs                      # C# WiFi transmitter
    ├── TeamsWiFiTransmitter.csproj    # Project file
    ├── Build.ps1                       # Build script
    └── README.md                       # Service documentation
```

## Quick Start

### 1. Hardware Setup
- **ESP32 DevKit** board (any variant)
- **RGB LED** (common cathode) + 3x 220Ω resistors
- **Wiring**:
  - GPIO 25 → Red (via resistor)
  - GPIO 26 → Green (via resistor)
  - GPIO 27 → Blue (via resistor)
  - GND → LED common cathode

### 2. Firmware Setup
```bash
# 1. Open Arduino IDE
# 2. Install ESP32 board support
# 3. Edit WiFi credentials in TeamsStatus_WiFi.ino
# 4. Upload to ESP32
# 5. Note IP address from Serial Monitor
```

### 3. PC Software Setup
```powershell
# Option A: Download pre-built
TeamsWiFiTransmitter.exe http://teams-status.local

# Option B: Build from source
cd dotnet_wifi_service
.\Build.ps1
```

See [esp32_firmware/QUICKSTART.md](esp32_firmware/QUICKSTART.md) for step-by-step instructions.

## Network Protocol

### HTTP API Endpoints

#### POST /status
Update Teams status
```http
POST /status HTTP/1.1
Host: teams-status.local
Content-Type: application/json

{"status": 0}
```

**Status Codes**:
```
0  = Available     (Green)
1  = Busy          (Red)
2  = Away          (Yellow)
3  = Be Right Back (Yellow)
4  = Do Not Disturb (Purple)
5  = Focusing      (Purple)
6  = Presenting    (Red)
7  = In a Meeting  (Red)
8  = In a Call     (Red)
9  = Offline       (Dim Gray)
10 = Unknown       (White)
```

#### GET /
Web interface with real-time status display

#### GET /api/current
Get current status
```json
{
  "status": 0,
  "timestamp": 1234567890
}
```

#### GET /api/health
Health check
```json
{
  "status": "healthy",
  "uptime": 3600,
  "wifi_rssi": -45
}
```

## Code Comparison: WiFi vs BLE

### ESP32 WiFi Firmware
```cpp
// Simple HTTP POST handler
void handleStatus() {
    String body = server.arg("plain");
    int status = parseStatus(body);
    updateLED(status);
    server.send(200, "application/json", "{\"success\":true}");
}
```
**Lines of code**: ~100 (vs 270 for Simblee BLE)

### C# WiFi Client
```csharp
// Simple HTTP POST
var payload = new { status = (int)status };
var response = await httpClient.PostAsJsonAsync($"{esp32Address}/status", payload);
```
**Lines of code**: ~50 (vs 580 for BLE!)

## Performance Comparison

| Feature | WiFi (ESP32) | BLE (RFduino) |
|---------|-------------|---------------|
| **Code Complexity** | ⭐⭐ Simple | ⭐⭐⭐⭐⭐ Complex |
| **Reliability** | ⭐⭐⭐⭐⭐ Excellent | ⭐⭐⭐ Good |
| **Range** | 30-50m | 10m |
| **Setup Time** | 5 minutes | 15 minutes |
| **Debugging** | Easy (web interface) | Hard (BLE logs) |
| **Windows Compatibility** | Perfect | Has quirks |
| **Power** | USB only | Battery capable |
| **Network Required** | Yes | No |

## Troubleshooting

### Common Issues

**1. Can't find `teams-status.local`**
```powershell
# Use IP address directly
TeamsWiFiTransmitter.exe http://192.168.1.123
```

**2. ESP32 won't connect to WiFi**
- Check SSID/password
- Use 2.4GHz network (ESP32 doesn't support 5GHz)
- Move closer to router
- Check MAC filtering on router

**3. LED doesn't change**
- Verify wiring (common cathode vs anode)
- Check resistor values (220Ω)
- Test with web interface
- Verify status updates in Serial Monitor

**4. Teams status not detected**
- Ensure Teams is running
- Change status manually to test
- Check log file exists:
  - New Teams: `%AppData%\Microsoft\Teams\logs.txt`
  - Classic Teams: `%AppData%\Microsoft\Teams\logs\MSTeams.log`

## Security Considerations

### Network Security
- WiFi credentials stored in ESP32 flash memory
- Use WPA2/WPA3 encrypted networks
- Consider guest/IoT network for isolation
- HTTP is unencrypted (could add HTTPS)

### Corporate Networks
- Works on most corporate WiFi
- No firewall rules needed (outbound HTTP only)
- No port forwarding required
- mDNS may not work across VLANs

## Advanced Configuration

### Static IP
```cpp
IPAddress staticIP(192, 168, 1, 100);
IPAddress gateway(192, 168, 1, 1);
IPAddress subnet(255, 255, 255, 0);
WiFi.config(staticIP, gateway, subnet);
```

### Custom Hostname
```cpp
const char* MDNS_HOSTNAME = "my-teams-light";
// Access via: http://my-teams-light.local
```

### Different Pins
```cpp
const int RED_PIN = 16;
const int GREEN_PIN = 17;
const int BLUE_PIN = 18;
```

### HTTPS (Advanced)
Add ESP32 SSL/TLS support for encrypted communication.

## Migration from BLE

If you're currently using the BLE (RFduino) implementation:

**What Stays the Same**:
- ✅ LED colors and status mapping
- ✅ Teams log parsing logic
- ✅ Update frequency (5 seconds)

**What Changes**:
- ❌ Replace RFduino with ESP32
- ❌ Replace `TeamsBLETransmitter.exe` with `TeamsWiFiTransmitter.exe`
- ❌ Update startup scripts with new executable

**Benefits of Switching**:
- ✅ 3-5x better range
- ✅ More reliable connection
- ✅ Web interface for monitoring
- ✅ Easier debugging

## Support

For detailed setup instructions:
- [esp32_firmware/README.md](esp32_firmware/README.md) - Complete guide
- [esp32_firmware/QUICKSTART.md](esp32_firmware/QUICKSTART.md) - 5-minute setup

For issues:
- Check troubleshooting sections
- Open GitHub issue
- ESP32 community forums

## Future Enhancements

Potential improvements:
- 🔧 HTTPS support
- 🔧 Deep sleep mode (battery operation)
- 🔧 OLED/LCD display
- 🔧 RGB LED strip support
- 🔧 Physical button control
- 🔧 Home Assistant integration
- 🔧 Multiple device broadcasting

---

**Ready to get started?** See [esp32_firmware/QUICKSTART.md](esp32_firmware/QUICKSTART.md) for 5-minute setup!
