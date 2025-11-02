# Arduino Setup Guide - Feather M0 WiFi + LED Matrix

Quick setup guide for the Arduino version of the Teams Status Monitor.

## Required Libraries

Install these libraries via Arduino IDE Library Manager (`Sketch` → `Include Library` → `Manage Libraries...`):

1. **WiFi101** - by Arduino (for ATWINC1500 WiFi chip)
2. **Adafruit GFX Library** - by Adafruit
3. **Adafruit IS31FL3731 Library** - by Adafruit

## Arduino IDE Setup

### Step 1: Install Arduino IDE

Download from: https://www.arduino.cc/en/software

### Step 2: Add Adafruit Board Support

1. Open Arduino IDE
2. Go to `File` → `Preferences`
3. In "Additional Boards Manager URLs", add:
   ```
   https://adafruit.github.io/arduino-board-index/package_adafruit_index.json
   ```
4. Click OK
5. Go to `Tools` → `Board` → `Boards Manager...`
6. Search for "Adafruit SAMD"
7. Install "Adafruit SAMD Boards"

### Step 3: Select Board

1. Go to `Tools` → `Board` → `Adafruit SAMD (32-bits ARM Cortex-M0+ and Cortex-M4) Boards`
2. Select **"Adafruit Feather M0"** (not M0 Express!)

### Step 4: Install Libraries

1. Go to `Sketch` → `Include Library` → `Manage Libraries...`
2. Install these libraries:
   - **WiFi101** (Search: "WiFi101" by Arduino)
   - **Adafruit GFX Library** (Search: "Adafruit GFX")
   - **Adafruit IS31FL3731** (Search: "Adafruit IS31FL3731")

## Upload Code

### Step 1: Configure WiFi

Edit `TeamsStatus_Feather_WiFi.ino`:

```cpp
// Line 30-31
const char* ssid = "YourWiFiName";
const char* password = "YourPassword";
```

### Step 2: Connect Hardware

1. Stack LED Matrix FeatherWing on Feather M0 WiFi
2. Connect Feather to computer via USB cable

### Step 3: Select Port

1. Go to `Tools` → `Port`
2. Select the COM port for your Feather (e.g., COM3, COM4)
   - Windows: `COM#`
   - Mac: `/dev/cu.usbmodem######`
   - Linux: `/dev/ttyACM#`

### Step 4: Upload

1. Click the **Upload** button (→) or press `Ctrl+U`
2. Wait for compilation and upload (30-60 seconds)
3. Look for "Done uploading" message

### Step 5: Open Serial Monitor

1. Go to `Tools` → `Serial Monitor` or press `Ctrl+Shift+M`
2. Set baud rate to **115200**
3. You should see:

```
==================================================
Teams Status Monitor - Feather M0 WiFi SERVER
==================================================

Initializing IS31FL3731 LED Matrix... OK
Checking WiFi module... OK
WiFi Firmware version: 19.6.1
Connecting to WiFi: YourWiFiName
...........

Connected!
IP Address: 192.168.1.100
Signal strength: -45 dBm

HTTP server started on port 80

Work PC should send POST to:
  http://192.168.1.100/status

JSON format:
  {"status": 0}  // 0-10

==================================================

Ready! Waiting for requests...
```

4. **Note the IP address!** You'll need it for the Work PC client.

## Configure Work PC Client

Use the same PowerShell client as before:

1. Edit `TeamsStatusClient.ps1`
2. Update the Feather IP address:

```powershell
$FeatherIP = "192.168.1.100"  # Use IP from Serial Monitor
```

3. Run the PowerShell script:

```powershell
.\TeamsStatusClient.ps1
```

## Testing

### Test 1: Browser Test

Visit `http://192.168.1.100/` (use your Feather's IP) in a web browser.

You should see a status page showing:
- IP Address
- Current Status
- Request count
- API endpoint info

### Test 2: Manual API Test

Using PowerShell:

```powershell
$ip = "192.168.1.100"
$body = @{ status = 1 } | ConvertTo-Json
Invoke-RestMethod -Uri "http://$ip/status" -Method POST -Body $body -ContentType "application/json"
```

The LED Matrix should turn solid red (Busy status).

### Test 3: Health Check

```powershell
Invoke-RestMethod -Uri "http://192.168.1.100/health"
```

Should return:
```json
{
  "status": "healthy",
  "ip": "192.168.1.100",
  "output": "LED_MATRIX",
  "rssi": -45
}
```

## Troubleshooting

### Compilation Errors

**Error:** `fatal error: WiFi101.h: No such file or directory`

**Solution:** Install WiFi101 library via Library Manager

**Error:** `fatal error: Adafruit_IS31FL3731.h: No such file or directory`

**Solution:** Install Adafruit IS31FL3731 library via Library Manager

**Error:** `'class Adafruit_IS31FL3731_Wing' has no member named 'begin'`

**Solution:** Update Adafruit IS31FL3731 library to latest version

### Upload Errors

**Error:** `No device found on COM#`

**Solution:**
1. Check USB cable is connected
2. Try pressing RESET button twice quickly (enter bootloader)
3. Verify correct board selected (`Tools` → `Board`)
4. Try different USB port

**Error:** `Upload failed`

**Solution:**
1. Double-tap RESET button to enter bootloader mode
2. Port should change to `FEATHERBOOT` or similar
3. Try upload again immediately

### WiFi Connection Issues

**Error:** `WiFi connection FAILED!`

**Solutions:**
1. Check SSID and password are correct
2. Ensure WiFi is 2.4GHz (not 5GHz)
3. Move Feather closer to router
4. Check Serial Monitor for error messages

### LED Matrix Issues

**Error:** `IS31FL3731 LED Matrix FAILED!`

**Solutions:**
1. Verify FeatherWing is properly seated on Feather
2. Check I2C connections (SCL/SDA)
3. Verify library is installed correctly
4. Try different I2C address if modified

## Serial Monitor Tips

### View Debug Output

Keep Serial Monitor open to see:
- WiFi connection status
- IP address
- Incoming HTTP requests
- Status changes
- Error messages

### Restart Feather

Press the **RESET** button on the Feather to restart the program.

### View Real-time Updates

Serial Monitor shows each status change:
```
New client connected
POST /status
Body: {"status":1}
Status updated: Busy (1)
Client disconnected
```

## Performance Notes

### Memory Usage

Arduino sketch uses:
- **Flash:** ~40KB / 256KB (15%)
- **RAM:** ~10KB / 32KB (31%)

Plenty of room for additional features!

### WiFi Performance

- **Connection time:** 2-5 seconds
- **HTTP response time:** 50-100ms
- **Concurrent connections:** 1 (WiFi101 limitation)

### LED Matrix Updates

- **Update time:** <10ms
- **Patterns:** Fully customizable in `updateDisplay()` function

## Customization

### Change LED Patterns

Edit the `updateDisplay()` function (line ~448) to create custom patterns for each status.

Example - Pulse effect:
```cpp
case AVAILABLE:  // Green - Pulsing brightness
  static uint8_t pulseValue = 0;
  pulseValue = (pulseValue + 1) % 255;

  for (int y = 0; y < 7; y++) {
    for (int x = 0; x < 15; x++) {
      matrix.drawPixel(x, y, pulseValue);
    }
  }
  break;
```

### Add Animations

You can add animations by updating the matrix in the `loop()` function:

```cpp
void loop() {
  WiFiClient client = server.available();

  if (client) {
    handleClient(client);
  }

  // Add animation here
  // e.g., scroll text, pulse brightness, etc.
}
```

### Custom HTTP Endpoints

Add new endpoints by modifying the `handleClient()` function:

```cpp
else if (requestPath.startsWith("/custom")) {
  handleCustomRequest(client);
}
```

## Next Steps

Once everything is working:

1. **Set up automatic startup** (see main README.md)
2. **Mount the Feather** somewhere visible on your desk
3. **Optional:** Add LiPo battery for wireless operation
4. **Customize patterns** to your liking

## Additional Resources

- **Feather M0 WiFi Guide:** https://learn.adafruit.com/adafruit-feather-m0-wifi-atwinc1500
- **IS31FL3731 Guide:** https://learn.adafruit.com/led-charlieplexed-matrix-featherwing
- **WiFi101 Library Docs:** https://www.arduino.cc/en/Reference/WiFi101
- **Adafruit Forums:** https://forums.adafruit.com/

---

**Enjoy your Arduino-powered Teams status display!** 🎉
