# PyPortal Installation Guide - Complete Step-by-Step

**Complete guide with screenshots and exact files needed.**

## What You'll Need

### Hardware
- ✅ Adafruit PyPortal (any variant)
- ✅ USB cable (must be data-capable, not charge-only!)
- ✅ Computer (Windows, Mac, or Linux)

### Software Downloads
We'll download these in the steps below:
1. CircuitPython firmware (`.uf2` file)
2. CircuitPython library bundle (`.zip` file)
3. This project's code

**Total time**: 10-15 minutes

---

## Step 1: Download CircuitPython Firmware (2 minutes)

### 1.1 Go to CircuitPython.org
- Open browser to: [https://circuitpython.org/board/pyportal/](https://circuitpython.org/board/pyportal/)

### 1.2 Download Latest Stable Version
- Click **"Download .UF2 Now"** button
- This downloads a file like: `adafruit-circuitpython-pyportal-en_US-9.2.1.uf2`
- Save to your **Desktop** or **Downloads** folder

**Note**: If you have PyPortal Titano or Pynt, use their specific pages:
- PyPortal Titano: [circuitpython.org/board/pyportal_titano/](https://circuitpython.org/board/pyportal_titano/)
- PyPortal Pynt: [circuitpython.org/board/pyportal_pynt/](https://circuitpython.org/board/pyportal_pynt/)

---

## Step 2: Install CircuitPython on PyPortal (3 minutes)

### 2.1 Connect PyPortal to Computer
- Plug USB cable into PyPortal
- Plug other end into computer
- PyPortal screen should light up (may show old code)

### 2.2 Enter Bootloader Mode
- Find the **RESET button** on the back of PyPortal (top middle)
- **Double-click** the reset button quickly (like double-clicking a mouse)
  - Not too slow (won't work)
  - Not too fast (won't work)
  - Just like a normal double-click
- You should see:
  - ✅ NeoPixel LED turns **GREEN** (good!)
  - ❌ If LED turns **RED**: bad USB cable or port, try different cable/port

### 2.3 Verify Bootloader Drive Appears
- A new drive should appear on your computer called: **PORTALBOOT**
  - **Windows**: Shows in File Explorer under "This PC"
  - **Mac**: Shows on Desktop
  - **Linux**: Shows in file manager (may auto-mount to `/media/username/PORTALBOOT`)

### 2.4 Copy Firmware File
- Drag the `.uf2` file you downloaded onto the **PORTALBOOT** drive
- **DO NOT** try to open files on PORTALBOOT, just drag the .uf2 onto it
- The LED will flash rapidly
- After a few seconds:
  - PORTALBOOT drive disappears
  - A new drive called **CIRCUITPY** appears ✅

### 2.5 Verify Installation
- Open the **CIRCUITPY** drive
- You should see these files:
  - `boot_out.txt` (contains CircuitPython version info)
  - `lib/` folder (may be empty)
  - `code.py` (may not exist yet - this is normal!)

**Congratulations!** CircuitPython is now installed! 🎉

---

## Step 3: Download CircuitPython Libraries (2 minutes)

### 3.1 Go to Libraries Page
- Open browser to: [https://circuitpython.org/libraries](https://circuitpython.org/libraries)

### 3.2 Download the Correct Bundle
**IMPORTANT**: Download the bundle that **matches your CircuitPython version**!

- Find your version in `CIRCUITPY/boot_out.txt`:
  ```
  Adafruit CircuitPython 9.2.1 on 2024-11-20; Adafruit PyPortal with samd51j20
  ```
  This shows **version 9.x**

- Download the **9.x Bundle**:
  - Click: **"Download Adafruit CircuitPython Library Bundle for Version 9.x"**
  - File name: `adafruit-circuitpython-bundle-9.x-mpy-yyyymmdd.zip`
  - Save to **Desktop** or **Downloads**

### 3.3 Extract the Bundle
- **Windows**: Right-click → "Extract All"
- **Mac**: Double-click the .zip file
- **Linux**: `unzip adafruit-circuitpython-bundle-9.x-mpy-*.zip`

You'll now have a folder like: `adafruit-circuitpython-bundle-9.x-mpy-20241201/`

---

## Step 4: Copy Required Libraries (3 minutes)

### 4.1 Open the Library Bundle Folder
Navigate to the extracted folder, then go into the **lib** subfolder:
```
adafruit-circuitpython-bundle-9.x-mpy-20241201/
└── lib/               ← Open this folder
    ├── adafruit_httpserver/
    ├── adafruit_display_text/
    ├── neopixel.mpy
    └── ... (hundreds more)
```

### 4.2 Create lib Folder on PyPortal (if needed)
- Open the **CIRCUITPY** drive
- If there's **no `lib` folder**, create one:
  - Right-click → New → Folder → Name it `lib`

### 4.3 Copy These EXACT Libraries

From the bundle's `lib/` folder, copy these **4 items** to `CIRCUITPY/lib/`:

#### ✅ Copy These Folders:
1. **`adafruit_httpserver/`** (entire folder)
   - This is a **folder** containing multiple files
   - Copy the entire folder, not individual files inside it

2. **`adafruit_display_text/`** (entire folder)
   - This is also a **folder**
   - Copy the entire folder

#### ✅ Copy These Files:
3. **`neopixel.mpy`** (single file)
   - This is a **file**, not a folder
   - Just copy this one file

4. **`adafruit_connection_manager.mpy`** (single file)
   - Another single **file**
   - Copy this file

### 4.4 Verify Library Installation
Your `CIRCUITPY/lib/` folder should now look like this:
```
CIRCUITPY/
└── lib/
    ├── adafruit_httpserver/       ← FOLDER
    │   ├── __init__.mpy
    │   ├── request.mpy
    │   ├── response.mpy
    │   └── server.mpy
    ├── adafruit_display_text/     ← FOLDER
    │   ├── __init__.mpy
    │   ├── label.mpy
    │   └── ...
    ├── neopixel.mpy               ← FILE
    └── adafruit_connection_manager.mpy  ← FILE
```

**Important Notes**:
- ✅ Folders contain multiple `.mpy` files inside them
- ✅ Single files are just one `.mpy` file each
- ✅ `.mpy` files are compiled Python modules (smaller and faster than `.py`)

---

## Step 5: Configure WiFi in Code (1 minute)

### 5.1 Open the Code File
- From **this repository**, find: `pyportal_firmware/code.py`
- Open it in **any text editor**:
  - Windows: Notepad, VS Code, Notepad++
  - Mac: TextEdit (in plain text mode), VS Code
  - Linux: gedit, nano, VS Code

### 5.2 Find WiFi Configuration Lines
Near the top of the file (around line 25), find:
```python
WIFI_SSID = "YOUR_WIFI_SSID"
WIFI_PASSWORD = "YOUR_WIFI_PASSWORD"
```

### 5.3 Update WiFi Credentials
Change to your actual WiFi network:
```python
WIFI_SSID = "CompanyWiFi-5G"        # Your WiFi name
WIFI_PASSWORD = "MySecurePassword"   # Your WiFi password
```

**Important**:
- ⚠️ Keep the **quotes** around the text
- ⚠️ PyPortal only supports **2.4GHz WiFi** (not 5GHz)
- ⚠️ Use your **work WiFi** if using at work

### 5.4 Save the File
- Save the file (keep the name as `code.py`)
- Make sure it's saved with **.py extension**, not .txt

---

## Step 6: Copy Code to PyPortal (1 minute)

### 6.1 Copy to CIRCUITPY Drive
- Take the **edited** `code.py` file
- Copy it to the **root** of the `CIRCUITPY` drive
- If there's already a `code.py` there, **replace** it

**Final file structure**:
```
CIRCUITPY/
├── boot_out.txt           ← Already there
├── code.py                ← YOUR file goes here
└── lib/                   ← Folder you created
    ├── adafruit_httpserver/
    ├── adafruit_display_text/
    ├── neopixel.mpy
    └── adafruit_connection_manager.mpy
```

### 6.2 PyPortal Auto-Restarts
- As soon as you save `code.py`, PyPortal will **automatically restart**
- The screen will refresh
- Code will start running immediately!

---

## Step 7: Verify It's Working (2 minutes)

### 7.1 Watch the PyPortal Display
You should see:
```
┌────────────────────────────────┐
│   Teams Status                 │  ← Title
│                                │
│   Connecting to WiFi...        │  ← Connection status
│                                │
└────────────────────────────────┘
```

Then after a few seconds:
```
┌────────────────────────────────┐
│   Teams Status                 │
│                                │
│   Unknown                      │  ← Status (white background)
│                                │
│   Waiting for status...        │
│   IP: 192.168.1.123            │  ← NOTE THIS IP!
└────────────────────────────────┘
```

### 7.2 Write Down the IP Address
- The bottom of the screen shows: `IP: 192.168.1.xxx`
- **Write this down** - you'll need it for the PC software!

### 7.3 Test Web Interface
- Open a web browser (on any device on the same WiFi)
- Try both:
  - `http://teams-status.local` (mDNS, may not work on all networks)
  - `http://192.168.1.123` (use the IP from display)
- You should see the **Teams Status Monitor** web page! 🎉

---

## Step 8: Troubleshooting (if needed)

### ❌ PORTALBOOT Drive Doesn't Appear

**Problem**: Double-clicking reset doesn't show PORTALBOOT

**Solutions**:
1. ✅ Try a **different USB cable** (must support data, not just charging)
2. ✅ Try a **different USB port** on your computer
3. ✅ Double-click **faster** (1-2 times per second)
4. ✅ Double-click **slower** (wait for LED to flash between clicks)
5. ✅ Press and hold reset for 1 second, release, then double-click

### ❌ Error: "ImportError: no module named 'adafruit_httpserver'"

**Problem**: Missing library files

**Solutions**:
1. ✅ Check `CIRCUITPY/lib/` has `adafruit_httpserver/` **folder** (not file)
2. ✅ Verify CircuitPython version matches library bundle version
3. ✅ Re-download library bundle if corrupted
4. ✅ Make sure you copied the **folder**, not just files inside it

### ❌ WiFi Connection Failed (Red Blinking LED)

**Problem**: Can't connect to WiFi

**Solutions**:
1. ✅ Check SSID and password in `code.py` (case-sensitive!)
2. ✅ Verify using **2.4GHz WiFi** (PyPortal doesn't support 5GHz)
3. ✅ Move PyPortal closer to router
4. ✅ Try a different WiFi network (guest network, phone hotspot)
5. ✅ Check router's MAC address filtering

### ❌ Display Shows Blank or Frozen

**Problem**: Code not running or crashed

**Solutions**:
1. ✅ Press the **reset button once** (single click) to restart
2. ✅ Check serial console for error messages (see below)
3. ✅ Verify `code.py` has correct Python syntax
4. ✅ Re-copy `code.py` from repository

### ❌ Can't Access teams-status.local

**Problem**: mDNS hostname not working

**Solutions**:
1. ✅ Use **IP address** instead (shown on PyPortal display)
2. ✅ Make sure computer and PyPortal are on **same WiFi network**
3. ✅ Disable **VPN** if active on computer
4. ✅ Windows: Enable "Bonjour Service" in services
5. ✅ Try from phone/tablet instead

---

## Advanced: Serial Console Debugging

If you want to see detailed debug output:

### Windows
1. Download [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)
2. Open Device Manager → Ports → Find "USB Serial Device (COMx)"
3. Open PuTTY: Serial, COM port = COMx, Speed = 115200
4. Press reset on PyPortal to see boot messages

### Mac/Linux
```bash
# Find the device
ls /dev/tty.*  # Mac
ls /dev/ttyACM*  # Linux

# Connect (Mac example)
screen /dev/tty.usbmodem14201 115200

# Exit: Ctrl+A then K then Y
```

**You'll see**:
```
==================================================
Teams Status Monitor - PyPortal
==================================================

Connecting to WiFi: YourSSID
[OK] Connected!
IP Address: 192.168.1.123
Signal: -45 dBm

[OK] mDNS started: http://teams-status.local
[OK] Starting HTTP server on port 80...

Ready to receive Teams status updates!
==================================================
```

---

## File Checklist

### ✅ Files You Downloaded:
- [ ] `adafruit-circuitpython-pyportal-*.uf2` (firmware)
- [ ] `adafruit-circuitpython-bundle-9.x-mpy-*.zip` (library bundle)
- [ ] `code.py` (from this repository)

### ✅ Files on CIRCUITPY Drive:
```
CIRCUITPY/
├── boot_out.txt                    ✅ Auto-created
├── code.py                         ✅ From this repo (edited)
└── lib/                            ✅ You created
    ├── adafruit_httpserver/        ✅ Folder from bundle
    ├── adafruit_display_text/      ✅ Folder from bundle
    ├── neopixel.mpy                ✅ File from bundle
    └── adafruit_connection_manager.mpy  ✅ File from bundle
```

---

## Next Step: Run PC Software

Now that PyPortal is set up, you need to run the **C# WiFi Transmitter** on your PC:

```powershell
# Using mDNS hostname
TeamsWiFiTransmitter.exe http://teams-status.local

# OR using IP address
TeamsWiFiTransmitter.exe http://192.168.1.123
```

See [../dotnet_wifi_service/](../dotnet_wifi_service/) for instructions on building/running the PC software.

---

## Success! 🎉

Your PyPortal should now:
- ✅ Show "Teams Status" on display
- ✅ Display "Unknown" status (white background)
- ✅ Show IP address at bottom
- ✅ NeoPixel glowing white
- ✅ Respond to web browser requests

**Ready for Teams status updates!**

---

## Need Help?

- Check [README.md](README.md) for detailed documentation
- See [QUICKSTART.md](QUICKSTART.md) for quick reference
- Open GitHub issue if problems persist

**Happy monitoring!** 🚦
