# Quick Start Guide - PowerShell Method

**Estimated Time**: 30-60 minutes to have a working system!

This guide will walk you through setting up the PowerShell log monitoring method for your MS Teams Presence PyPortal project.

---

## Prerequisites

✅ Windows computer with admin access
✅ Microsoft Teams installed and running
✅ Adafruit PyPortal device
✅ WiFi network (2.4GHz)

---

## Phase 1: Test Your Computer Setup (10 minutes)

### Step 1: Run Diagnostics

Open PowerShell and navigate to the project directory:

```powershell
cd D:\Repos\MSTeams-Presence-Notify\powershell_service
```

Run the diagnostic test:

```powershell
powershell -ExecutionPolicy Bypass -File Test-TeamsStatus.ps1
```

**Expected Output**:
```
========================================
Teams Status Server - Diagnostics
========================================

[1/6] Checking Teams installation...
  ✓ Teams is running
    Process ID: 12345

[2/6] Checking New Teams log directory...
  ✓ New Teams log directory found
    Path: C:\Users\...\MSTeams\Logs\
    Log files: 5

[3/6] Checking log content...
  ✓ Status patterns found in logs
    Detected: Available

[4/6] Checking port 8080 availability...
  ✓ Port 8080 is available

[5/6] Checking network configuration...
  ✓ Network adapters found
    192.168.1.100

  PyPortal should connect to: http://192.168.1.100:8080/status

[6/6] Testing server startup...
  ✓ Server started successfully!
    Status: Available
    Color: #00FF00

========================================
Summary
========================================

✓ All critical tests passed!

You're ready to run the Teams Status Server:
  powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1
```

### Troubleshooting Step 1

**Issue**: Teams is NOT running
- **Solution**: Start Microsoft Teams and run diagnostics again

**Issue**: No log files found
- **Solution**:
  1. Close Teams completely
  2. Restart Teams
  3. Change your status manually (Available → Busy → Available)
  4. Run diagnostics again

**Issue**: Port 8080 is already in use
- **Solution**:
  ```powershell
  # Find and kill the process
  netstat -ano | findstr :8080
  taskkill /F /PID <process-id>
  ```

### Step 2: Note Your IP Address

From the diagnostics output, note your computer's IP address.

Example: `192.168.1.100`

You'll need this for PyPortal configuration later!

---

## Phase 2: Start the Teams Status Server (5 minutes)

### Step 1: Run the Server

In PowerShell:

```powershell
cd D:\Repos\MSTeams-Presence-Notify\powershell_service
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1
```

**Expected Output**:
```
========================================
Teams Status HTTP Server for PyPortal
========================================

Configuration:
  Port: 8080
  Check Interval: 5 seconds
  Log Path: C:\Users\...\MSTeams\Logs\
  Debug Mode: False

✓ HTTP Server started on http://localhost:8080/
✓ PyPortal can connect to http://<your-ip>:8080/status

Press Ctrl+C to stop the server

========================================

Performing initial status check...
Initial status: Available

Background monitoring started (checking every 5 seconds)
```

### Step 2: Test the Server

**Open a NEW PowerShell window** (keep the server running in the first one):

```powershell
# Test the status endpoint
Invoke-WebRequest -Uri http://localhost:8080/status | ConvertFrom-Json
```

**Expected Response**:
```
availability activity  color
------------ --------  -----
Available    Available #00FF00
```

### Step 3: Test Status Changes

While the server is running:

1. Change your Teams status (Available → Busy)
2. Wait 5-10 seconds
3. Test the endpoint again:
   ```powershell
   Invoke-WebRequest -Uri http://localhost:8080/status | ConvertFrom-Json
   ```
4. Status should now show `Busy` with color `#FF0000`

### Troubleshooting Phase 2

**Issue**: Server won't start
- Check diagnostics output from Phase 1
- Ensure port 8080 is available
- Try running PowerShell as Administrator

**Issue**: Status shows "Unknown"
- Change your Teams status manually
- Run with debug mode:
  ```powershell
  powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1 -Debug
  ```
- Watch for status detection in console output

**Issue**: Status doesn't update
- Wait 5-10 seconds after changing Teams status
- Check that Teams is still running
- Restart the server

---

## Phase 3: PyPortal Setup (15 minutes)

### Step 1: Install CircuitPython on PyPortal

1. **Download CircuitPython**:
   - Visit: https://circuitpython.org/board/pyportal/
   - Download latest stable version (8.x or 9.x)

2. **Enter Bootloader Mode**:
   - Connect PyPortal to computer via USB-C
   - **Double-tap** the RESET button (small button on back)
   - Screen turns green, `PORTALBOOT` drive appears

3. **Install CircuitPython**:
   - Drag downloaded `.uf2` file to `PORTALBOOT` drive
   - PyPortal restarts automatically
   - `CIRCUITPY` drive appears

4. **Verify Installation**:
   - Open `CIRCUITPY` drive
   - Check `boot_out.txt` for CircuitPython version

### Step 2: Install Required Libraries

1. **Download CircuitPython Library Bundle**:
   - Visit: https://circuitpython.org/libraries
   - Download bundle matching your CircuitPython version
   - Extract the zip file

2. **Create lib folder on PyPortal**:
   - If `lib` folder doesn't exist on `CIRCUITPY` drive, create it

3. **Copy Required Libraries**:

   Copy these folders/files to `E:\lib\` (replace `E:` with your CIRCUITPY drive):

   ```
   From bundle\lib\ to E:\lib\:

   📁 adafruit_display_text\     (entire folder)
   📁 adafruit_bitmap_font\       (entire folder)
   📁 adafruit_esp32spi\          (entire folder)
   📁 adafruit_portalbase\        (entire folder)
   📄 adafruit_requests.mpy       (single file)
   ```

### Step 3: Configure WiFi

Create `secrets.py` on PyPortal root:

```python
# Copy this to E:\secrets.py (your CIRCUITPY drive)

secrets = {
    "ssid": "Your-WiFi-Name",           # Replace with your WiFi name
    "password": "Your-WiFi-Password",   # Replace with your WiFi password
    "server_url": "http://192.168.1.100:8080/status"  # Replace with YOUR IP from Phase 1
}
```

**IMPORTANT**: Replace `192.168.1.100` with YOUR computer's IP address from Phase 1!

---

## Phase 4: PyPortal Code (10 minutes)

### Step 1: Create PyPortal Code

I'll create the PyPortal code in the next step. For now, prepare your PyPortal by ensuring:

✅ CircuitPython is installed
✅ Libraries are copied
✅ `secrets.py` is configured with YOUR WiFi and YOUR IP

### Step 2: Test WiFi Connection

Create a simple test file to verify WiFi works:

**Save as `E:\code.py`**:

```python
import board
import busio
from digitalio import DigitalInOut
import adafruit_esp32spi.adafruit_esp32spi_socket as socket
from adafruit_esp32spi import adafruit_esp32spi

try:
    from secrets import secrets
except ImportError:
    print("WiFi secrets not found!")
    raise

print("Connecting to WiFi...")

# ESP32 SPI setup
esp32_cs = DigitalInOut(board.ESP_CS)
esp32_ready = DigitalInOut(board.ESP_BUSY)
esp32_reset = DigitalInOut(board.ESP_RESET)

spi = busio.SPI(board.SCK, board.MOSI, board.MISO)
esp = adafruit_esp32spi.ESP_SPIcontrol(spi, esp32_cs, esp32_ready, esp32_reset)

# Connect to WiFi
while not esp.is_connected:
    try:
        esp.connect_AP(secrets["ssid"], secrets["password"])
    except RuntimeError as e:
        print(f"Could not connect: {e}")
        continue

print("Connected!")
print(f"IP: {esp.pretty_ip(esp.ip_address)}")
print("\nWiFi test successful! Ready for full code.")

import time
while True:
    time.sleep(1)
```

**Connect to serial monitor** (using mu-editor or similar) and verify:
- WiFi connection successful
- IP address displayed

---

## Phase 5: Full Integration (15 minutes)

Once you've completed Phases 1-4, I'll provide the complete PyPortal code that:

✅ Connects to your WiFi
✅ Requests status from your computer
✅ Displays status with colors and text
✅ Updates every 30 seconds

---

## Current Status

You should now have:

✅ **Phase 1 Complete**: Computer diagnostics passing
✅ **Phase 2 Complete**: PowerShell server running and serving status
✅ **Phase 3 Complete**: PyPortal with CircuitPython, libraries, and WiFi configured
✅ **Phase 4 Complete**: PyPortal WiFi test working

---

## Next Steps

**Try these commands now**:

1. **Run diagnostics**:
   ```powershell
   cd D:\Repos\MSTeams-Presence-Notify\powershell_service
   powershell -ExecutionPolicy Bypass -File Test-TeamsStatus.ps1
   ```

2. **Start the server**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1
   ```

3. **Test the endpoint**:
   ```powershell
   Invoke-WebRequest -Uri http://localhost:8080/status | ConvertFrom-Json
   ```

**Let me know when you've completed these steps**, and I'll provide:
- ✅ Complete PyPortal code
- ✅ Auto-start configuration
- ✅ Troubleshooting for any issues

---

## Quick Reference

### Start Server
```powershell
cd D:\Repos\MSTeams-Presence-Notify\powershell_service
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1
```

### Test Status
```powershell
Invoke-WebRequest -Uri http://localhost:8080/status | ConvertFrom-Json
```

### Stop Server
Press `Ctrl+C` in the PowerShell window

### Your IP Address
```powershell
ipconfig | findstr IPv4
```

### Check Port Usage
```powershell
netstat -ano | findstr :8080
```

---

**Ready to start? Run the diagnostics and let me know how it goes!** 🚀
