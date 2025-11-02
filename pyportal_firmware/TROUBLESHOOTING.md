# PyPortal Troubleshooting - Common Errors

## Error: "ImportError: no module named 'wifi'"

**What it means**: The `wifi` module is built into CircuitPython 7.0+, but your PyPortal doesn't have it.

### Solution 1: Check CircuitPython Version (Most Common)

**Step 1**: Open the `CIRCUITPY` drive

**Step 2**: Open `boot_out.txt` file

**Step 3**: Check the first line:
```
Adafruit CircuitPython 9.2.1 on 2024-11-20; Adafruit PyPortal with samd51j20
```

**What you need**: Version **7.0 or higher** (9.x recommended)

**If you have version 6.x or lower**:
- ❌ Too old! The `wifi` module doesn't exist
- ✅ **Solution**: Update to CircuitPython 9.x

### How to Update CircuitPython

1. **Download latest version**: [circuitpython.org/board/pyportal](https://circuitpython.org/board/pyportal/)
   - Get version **9.2.x** or newer

2. **Enter bootloader**:
   - Double-click reset button on back of PyPortal
   - Drive changes from `CIRCUITPY` to `PORTALBOOT`

3. **Install new firmware**:
   - Drag the `.uf2` file onto `PORTALBOOT`
   - PyPortal will reboot
   - `CIRCUITPY` drive reappears

4. **Re-copy libraries and code**:
   - You'll need to copy libraries again (they get erased)
   - Copy `code.py` again

### Solution 2: Wrong Board Firmware

**Check boot_out.txt again**. It should say **"Adafruit PyPortal"**:
```
Adafruit CircuitPython 9.2.1 on 2024-11-20; Adafruit PyPortal with samd51j20
                                             ^^^^^^^^^^^^^^
```

**If it says a different board** (Metro, Feather, etc.):
- ❌ Wrong firmware installed!
- ✅ **Solution**: Download PyPortal-specific firmware from link above

---

## Error: "ImportError: no module named 'adafruit_httpserver'"

**What it means**: Missing library files in `lib/` folder

### Solution: Copy Libraries

Make sure your `CIRCUITPY/lib/` folder has:
```
lib/
├── adafruit_httpserver/      ← FOLDER (not just files)
├── adafruit_display_text/    ← FOLDER
├── neopixel.mpy              ← FILE
└── adafruit_connection_manager.mpy  ← FILE
```

**Common mistakes**:
- ❌ Copying individual files from inside `adafruit_httpserver/` folder
- ❌ Forgetting to copy the whole folder
- ✅ **Solution**: Copy the entire `adafruit_httpserver/` folder

---

## Error: WiFi Connection Failed (Red Blinking LED)

**What it means**: Can't connect to WiFi

### Solutions:

1. **Check WiFi credentials in code.py**:
   ```python
   WIFI_SSID = "C&D"           # Check spelling!
   WIFI_PASSWORD = "sienkows1"  # Check password!
   ```

2. **Use 2.4GHz WiFi only**:
   - ❌ PyPortal doesn't support 5GHz
   - ✅ Make sure your network is 2.4GHz
   - Many routers have separate 2.4GHz and 5GHz networks

3. **Move closer to router**:
   - Try right next to router first
   - Rule out range issues

4. **Try different network**:
   - Phone hotspot (set to 2.4GHz)
   - Guest network
   - Different router

---

## Error: Display Shows Nothing or Frozen

**What it means**: Code crashed or syntax error

### Solutions:

1. **Press reset button** (single click):
   - Restarts the code
   - Often fixes temporary issues

2. **Check serial console** for error messages:
   - Windows: Use PuTTY (115200 baud)
   - Mac: `screen /dev/tty.usbmodem* 115200`
   - Linux: `screen /dev/ttyACM0 115200`

3. **Verify code.py syntax**:
   - Open in a proper text editor
   - Check for missing quotes, colons, etc.

4. **Re-copy code.py from repository**:
   - Download fresh copy
   - Edit WiFi credentials again
   - Copy to CIRCUITPY

---

## Error: "OSError: [Errno 28] No space left on device"

**What it means**: PyPortal storage is full

### Solutions:

1. **Delete old files**:
   - Remove any old projects from CIRCUITPY
   - Keep only `boot_out.txt`, `code.py`, and `lib/`

2. **Use .mpy files instead of .py**:
   - ✅ Always use library bundle with `.mpy` files
   - ❌ Don't use `.py` source files (much bigger)

3. **Remove unused libraries**:
   - Only keep the 4 libraries needed for this project
   - Remove any others from `lib/`

---

## Web Interface Not Working

### Can't access `http://teams-status.local`

**Solutions**:
1. **Use IP address instead**:
   - Look at PyPortal display for IP
   - Use `http://192.168.1.xxx`

2. **Make sure on same network**:
   - Computer and PyPortal must be on same WiFi
   - Disable VPN if active

3. **Try from different device**:
   - Phone browser
   - Tablet
   - Different computer

### IP address works but `.local` doesn't

**This is normal!** mDNS doesn't work on all networks:
- Corporate networks often block mDNS
- Some routers don't support it
- Windows sometimes has issues

**Solution**: Just use the IP address - it works fine!

---

## Libraries Version Mismatch

### Error about library versions

**Solutions**:

1. **Match versions**:
   - CircuitPython **9.x** needs library bundle **9.x**
   - Check version in `boot_out.txt`
   - Download matching bundle from circuitpython.org/libraries

2. **Re-download bundle if needed**:
   - Delete old bundle
   - Download fresh one
   - Copy libraries again

---

## How to See Error Messages

### Serial Console (for detailed debugging)

**Windows with PuTTY**:
1. Download [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)
2. Device Manager → Ports → note COM number
3. PuTTY → Serial → COM# → 115200 baud
4. Reset PyPortal to see boot messages

**Mac/Linux**:
```bash
# Find device
ls /dev/tty.*      # Mac
ls /dev/ttyACM*    # Linux

# Connect
screen /dev/tty.usbmodem14201 115200  # Mac
screen /dev/ttyACM0 115200             # Linux

# Exit: Ctrl+A, then K, then Y
```

**What you'll see**:
```
Auto-reload is on. Simply save files over USB to run them or enter REPL to disable.
code.py output:

==================================================
Teams Status Monitor - PyPortal
==================================================

Connecting to WiFi: C&D
[OK] Connected!
IP Address: 192.168.1.123
...
```

---

## Complete Reset (Nuclear Option)

If nothing works, start fresh:

1. **Format CIRCUITPY** (will erase everything!):
   - Windows: Right-click CIRCUITPY → Format → FAT
   - Mac: Disk Utility → Erase → MS-DOS (FAT)
   - Linux: `sudo mkfs.vfat /dev/sdX1`

2. **Reinstall CircuitPython**:
   - Double-click reset
   - Drag .uf2 to PORTALBOOT

3. **Start over**:
   - Copy libraries
   - Copy code.py

---

## Still Having Issues?

1. **Check the guides**:
   - [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) - step-by-step
   - [FILES_TO_COPY.md](FILES_TO_COPY.md) - exact files needed

2. **Common solutions**:
   - Try different USB cable
   - Try different USB port
   - Restart computer
   - Update CircuitPython to 9.x

3. **Ask for help**:
   - Adafruit forums
   - CircuitPython Discord
   - GitHub issues for this project

**Most common issue**: Old CircuitPython version - update to 9.x! ✨
