# PyPortal Setup Guide - CLIENT MODE (Polling Architecture)

Complete setup guide for using the Adafruit PyPortal as a Teams status display.

## ⚠️ Important Architecture Note

**The PyPortal ESP32 coprocessor only supports CLIENT mode!**

This means the PyPortal **cannot run an HTTP server** - it can only make outgoing HTTP requests. This is a fundamental hardware/firmware limitation of the ESP32SPI library in CircuitPython.

### Solution: Polling Architecture

```
┌─────────────────────┐           ┌──────────────────────┐
│   Your PC           │           │   PyPortal           │
│                     │           │                      │
│  PowerShell Server  │◄──────────┤  HTTP Client         │
│  (TeamsStatusServer)│  Polls    │  (Displays status)   │
│  Port 8080          │  every 5s │                      │
└─────────────────────┘           └──────────────────────┘
```

**How it works:**
1. PC runs PowerShell HTTP server (port 8080)
2. PyPortal polls `http://<PC_IP>:8080/status` every 5 seconds
3. Server returns JSON: `{"availability":"Available","activity":"Available","color":"#00FF00"}`
4. PyPortal updates display and NeoPixel LED

---

## Part 1: PC Setup (PowerShell Server)

### Step 1: Start the PowerShell Server

```powershell
cd d:\Repos\MSTeams-Presence-Notify\powershell_service
.\TeamsStatusServer.ps1
```

**Optional parameters:**
```powershell
# Custom port (if 8080 is in use)
.\TeamsStatusServer.ps1 -Port 8081

# Enable debug logging
.\TeamsStatusServer.ps1 -Debug

# Change polling interval (default: 5 seconds)
.\TeamsStatusServer.ps1 -CheckInterval 10
```

### Step 2: Find Your PC's IP Address

**Method 1: Using ipconfig**
```powershell
ipconfig
```
Look for "IPv4 Address" under your active network adapter:
```
Wireless LAN adapter Wi-Fi:
   IPv4 Address. . . . . . . . . . . : 192.168.1.100  ← This is your IP!
```

**Method 2: Quick command**
```powershell
(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -like "*Wi-Fi*"}).IPAddress
```

### Step 3: Test the Server

Open a browser and navigate to:
```
http://localhost:8080/status
```

You should see JSON output like:
```json
{
  "availability": "Available",
  "activity": "Available",
  "color": "#00FF00"
}
```

### Step 4: Allow Firewall Access

**Option A: Windows Defender Firewall (Recommended)**

When you first run the server, Windows will ask for firewall permission. **Click "Allow access"**.

**Option B: Manual firewall rule**

If you missed the prompt, add a rule manually:

```powershell
# Run as Administrator
New-NetFirewallRule -DisplayName "Teams Status Server" `
  -Direction Inbound `
  -LocalPort 8080 `
  -Protocol TCP `
  -Action Allow
```

---

## Part 2: PyPortal Setup

### Hardware Required

- **Adafruit PyPortal** (any variant: standard, Pynt, or Titano)
- **USB-C cable** (for power and programming)
- **WiFi network** (2.4GHz - ESP32 doesn't support 5GHz)

### Step 1: Install CircuitPython

1. **Download CircuitPython**
   - Visit: https://circuitpython.org/board/pyportal/
   - Download the latest **stable release** (9.x or 10.x)

2. **Enter Bootloader Mode**
   - Double-click the **RESET button** on the back of the PyPortal
   - A drive named `PORTALBOOT` should appear

3. **Install CircuitPython**
   - Copy the downloaded `.uf2` file to the `PORTALBOOT` drive
   - PyPortal will reboot automatically
   - A new drive named `CIRCUITPY` will appear

### Step 2: Install Required Libraries

1. **Download Library Bundle**
   - Visit: https://circuitpython.org/libraries
   - Download the bundle matching your CircuitPython version (9.x or 10.x)
   - Extract the ZIP file

2. **Copy Libraries to PyPortal**

   From the extracted bundle, copy these folders to `CIRCUITPY/lib/`:

   ```
   CIRCUITPY/lib/
   ├── adafruit_esp32spi/          (entire folder)
   ├── adafruit_requests.mpy
   ├── adafruit_display_text/      (entire folder)
   └── neopixel.mpy
   ```

   **Note:** Your bundle may have `.py` or `.mpy` files. Either works!

### Step 3: Configure WiFi and Server Settings

1. **Copy the code file**

   Copy `d:\Repos\MSTeams-Presence-Notify\pyportal_firmware\code.py` to the `CIRCUITPY` drive.

2. **Edit `code.py` on the CIRCUITPY drive**

3. **Update WiFi credentials:**

   ```python
   # Line 33-34
   WIFI_SSID = "YourWiFiName"      # Your WiFi network name
   WIFI_PASSWORD = "YourPassword"   # Your WiFi password
   ```

4. **Update server IP address:**

   ```python
   # Line 38 - Use the IP from Part 1, Step 2
   SERVER_IP = "192.168.1.100"  # ⚠️ CHANGE THIS TO YOUR PC'S IP!
   ```

5. **Optional: Adjust polling interval**

   ```python
   # Line 43 - How often to check status (in seconds)
   POLL_INTERVAL = 5  # Default: check every 5 seconds
   ```

---

## Part 3: Testing

### Step 1: Check Serial Console

1. **Open a serial connection:**
   - **Windows:** Use [PuTTY](https://www.putty.org/) or [Tera Term](https://ttssh2.osdn.jp/index.html.en)
   - **macOS/Linux:** Use `screen /dev/ttyACM0 115200`
   - **Or:** Use the Arduino IDE Serial Monitor or Mu Editor

2. **You should see:**
   ```
   ==================================================
   Teams Status Monitor - PyPortal CLIENT
   ==================================================

   ESP32 Firmware: 1.7.4
   Connecting to WiFi: YourWiFiName
   ✓ Connected!
   IP Address: 192.168.1.105
   ✓ HTTP client ready
   Polling: http://192.168.1.100:8080/status
   Interval: 5 seconds

   ==================================================

   Starting polling loop...

   [14:30:15] Status: Available
   [14:30:20] Status: Available
   [14:30:25] Status: Busy
   ```

### Step 2: Watch the Display

The PyPortal display should show:

```
╔════════════════════════════╗
║    Teams Status            ║
║                            ║
║      Available             ║  (in GREEN)
║                            ║
║  Updated: 14:30:25         ║
║  IP: 192.168.1.105         ║
║  Server: 192.168.1.100:8080║
╚════════════════════════════╝
```

### Step 3: Test Status Changes

Change your Teams status and watch:
- **Display** updates within 5 seconds
- **NeoPixel** changes color to match
- **Serial console** logs the update

---

## Troubleshooting

### PyPortal Can't Connect to WiFi

**Problem:** Display shows "NO WIFI" with red flashing NeoPixel

**Solutions:**
1. **Check WiFi credentials**
   - Verify SSID and password are correct
   - Ensure no special characters or trailing spaces

2. **Check WiFi band**
   - ESP32 only supports **2.4GHz WiFi**
   - Cannot connect to 5GHz networks

3. **Check signal strength**
   - Move PyPortal closer to router
   - Reduce obstacles between PyPortal and router

4. **Update ESP32 firmware**
   - Follow: https://learn.adafruit.com/adafruit-pyportal/updating-esp32-firmware
   - Minimum version: 1.7.1

### PyPortal Can't Reach Server

**Problem:** Display shows "ERROR: Can't reach server"

**Solutions:**
1. **Verify server is running**
   - Check PowerShell window is still open
   - Look for "HTTP Server started" message

2. **Check IP address**
   - Confirm `SERVER_IP` in `code.py` matches PC's IP
   - Run `ipconfig` to verify current IP

3. **Test from another device**
   - On phone/tablet connected to same WiFi
   - Visit `http://192.168.1.100:8080/status`
   - Should see JSON response

4. **Check firewall**
   - Ensure Windows Firewall allows port 8080
   - Try temporarily disabling firewall to test

5. **Check both devices are on same network**
   - PyPortal and PC must be on same WiFi network
   - Guest networks may block device-to-device communication

### Status Not Updating

**Problem:** PyPortal connects but status doesn't change

**Solutions:**
1. **Check Teams is running**
   - PowerShell server detects Teams process
   - Status shows "Offline" if Teams is closed

2. **Check PowerShell console**
   - Look for "Status: X" messages
   - Server should update every 5 seconds

3. **Verify Teams version**
   - New Teams (recommended): Installed from Microsoft Store
   - Classic Teams: Support ends July 2025

4. **Check log file access**
   - PowerShell server needs read access to Teams logs
   - Path shown in PowerShell startup message

### Import/Library Errors

**Problem:** "ImportError: no module named 'adafruit_esp32spi'"

**Solutions:**
1. **Verify library installation**
   ```
   CIRCUITPY/lib/
   ├── adafruit_esp32spi/  ← Must be a FOLDER
   ```

2. **Check CircuitPython version**
   - Libraries must match CircuitPython version
   - 9.x libraries won't work with 10.x firmware

3. **Re-copy libraries**
   - Delete `CIRCUITPY/lib/` folder
   - Copy fresh libraries from bundle

### Display Issues

**Problem:** Display is blank or shows garbled text

**Solutions:**
1. **Check for error in serial console**
   - Connection errors show detailed messages

2. **Reset PyPortal**
   - Press RESET button once
   - Should see display initialize

3. **Update CircuitPython**
   - Download latest stable release
   - Re-install libraries to match version

---

## Status Color Reference

| Teams Status        | Display Color | Background    | NeoPixel |
|---------------------|---------------|---------------|----------|
| Available           | Green         | Dark Green    | Green    |
| Busy                | Red           | Dark Red      | Red      |
| In a Call           | Red           | Dark Red      | Red      |
| In a Meeting        | Red           | Dark Red      | Red      |
| Presenting          | Red           | Dark Red      | Red      |
| Do Not Disturb      | Purple        | Dark Purple   | Purple   |
| Focusing            | Purple        | Dark Purple   | Purple   |
| Away                | Yellow        | Dark Yellow   | Yellow   |
| Be Right Back       | Yellow        | Dark Yellow   | Yellow   |
| Offline             | Gray          | Dark Gray     | Dim Gray |
| Unknown             | White         | Dark Gray     | White    |

---

## Advanced Configuration

### Change Polling Interval

Edit `code.py`:
```python
POLL_INTERVAL = 10  # Check every 10 seconds instead of 5
```

**Trade-offs:**
- **Shorter (1-3s):** More responsive, more network traffic
- **Longer (10-30s):** Less responsive, less network traffic

### Adjust Display Brightness

Edit `code.py`:
```python
display.brightness = 0.8  # Range: 0.0 (off) to 1.0 (full)
```

### Adjust NeoPixel Brightness

Edit `code.py`:
```python
pixel = neopixel.NeoPixel(board.NEOPIXEL, 1, brightness=0.3)
# Range: 0.0 (off) to 1.0 (full)
```

### Change Server Port

**On PC (PowerShell):**
```powershell
.\TeamsStatusServer.ps1 -Port 8081
```

**On PyPortal (code.py):**
```python
SERVER_PORT = 8081
```

---

## Automatic Startup

### Auto-start PowerShell Server (Windows)

**Option 1: Task Scheduler (Runs at login)**

1. Open Task Scheduler
2. Create Basic Task:
   - **Name:** Teams Status Server
   - **Trigger:** At log on
   - **Action:** Start a program
   - **Program:** `powershell.exe`
   - **Arguments:**
     ```
     -ExecutionPolicy Bypass -File "d:\Repos\MSTeams-Presence-Notify\powershell_service\TeamsStatusServer.ps1"
     ```

**Option 2: Startup Folder (Quick method)**

1. Press `Win + R`, type `shell:startup`, press Enter
2. Create a shortcut to your script:
   - Right-click → New → Shortcut
   - Location:
     ```
     powershell.exe -ExecutionPolicy Bypass -File "d:\Repos\MSTeams-Presence-Notify\powershell_service\TeamsStatusServer.ps1"
     ```

### PyPortal Auto-runs on Power

The PyPortal automatically runs `code.py` when powered on - no configuration needed!

---

## Performance Notes

### Network Usage

- **Polling frequency:** Every 5 seconds
- **Request size:** ~200 bytes
- **Response size:** ~100 bytes
- **Bandwidth:** ~0.05 KB/s (negligible)

### Power Consumption

- **Active:** ~1W (USB powered)
- **Display:** Adjustable brightness to save power
- **NeoPixel:** Minimal power draw

### ESP32 Limitations

- **Client mode only:** Cannot run servers (hardware limitation)
- **2.4GHz WiFi only:** No 5GHz support
- **Single connection:** One request at a time
- **No SSL on old firmware:** Update to 1.7.1+ for HTTPS

---

## Why CLIENT Mode Instead of SERVER Mode?

### The Technical Reality

The ESP32 coprocessor on the PyPortal uses CircuitPython's `adafruit_esp32spi` library, which is designed for **client operations only**:

✅ **Supported (Client Mode):**
- Making HTTP GET/POST requests
- Fetching web pages
- API calls
- Downloading data

❌ **NOT Supported (Server Mode):**
- Accepting incoming connections
- Running HTTP servers
- Socket `bind()` operations
- Listening on ports

### Why This Architecture is Actually Better

**Advantages of Polling (Client Mode):**
1. ✅ **No firewall issues** - Only outbound connections
2. ✅ **Simpler network setup** - No port forwarding needed
3. ✅ **Works with strict networks** - Most networks allow outbound HTTP
4. ✅ **Easier troubleshooting** - Standard HTTP client behavior

**Disadvantages:**
1. ⚠️ Slightly higher latency (up to 5 seconds delay)
2. ⚠️ PC must run a server (but PowerShell script handles this)
3. ⚠️ More network traffic (but negligible - only 60 bytes/second)

---

## Alternative Hardware Options

If you **absolutely must** have a device that accepts incoming connections:

### Option 1: Plain ESP32 DevKit

Use the **esp32_firmware/** folder in this repo:
- ✅ Can run HTTP servers
- ✅ Full WiFi support
- ✅ Direct control over ESP32
- ❌ Requires wiring an RGB LED
- ❌ No built-in display
- **Cost:** $8-12

### Option 2: ESP32-based Display Boards

- **LilyGO T-Display** ($15-20) - Built-in 1.14" display
- **M5Stack Core** ($30-40) - 2" display + buttons
- **TTGO T-Display S3** ($15-20) - 1.9" display
- All support server mode and have full ESP32 capabilities

### Why Still Choose PyPortal?

Despite the client-mode limitation, PyPortal is still the best option because:
- ✅ **3.2" color display** (much larger than alternatives)
- ✅ **Zero wiring** (everything built-in)
- ✅ **CircuitPython** (easier to program than C++)
- ✅ **Professional appearance** (not a breadboard mess)
- ✅ **Touch screen** (for future enhancements)
- ✅ **Built-in NeoPixel** (no wiring needed)

---

## Support

### Official Adafruit Resources

- **PyPortal Guide:** https://learn.adafruit.com/adafruit-pyportal
- **CircuitPython Guide:** https://learn.adafruit.com/welcome-to-circuitpython
- **ESP32 Firmware Update:** https://learn.adafruit.com/adafruit-pyportal/updating-esp32-firmware
- **Forums:** https://forums.adafruit.com/

### This Project

- **Repository:** d:\Repos\MSTeams-Presence-Notify
- **ESP32 Alternative:** See `esp32_firmware/` folder
- **PowerShell Service:** See `powershell_service/` folder

---

## License

This project is based on:
- **EBOOZ/TeamsStatus** - Original PowerShell monitoring logic
- **Adafruit CircuitPython** - Display and WiFi libraries

Licensed under MIT License.
