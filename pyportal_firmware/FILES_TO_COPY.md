# Exact Files to Copy - PyPortal (CORRECTED)

**Updated for PyPortal's ESP32 SPI WiFi coprocessor**

---

## Step 1: Download These Files

### ✅ CircuitPython Firmware
**Download from**: [circuitpython.org/board/pyportal](https://circuitpython.org/board/pyportal/)

**File**: `adafruit-circuitpython-pyportal-en_US-10.0.3.uf2` (or any 9.x/10.x version)

**What to do**: Drag this onto `PORTALBOOT` drive when PyPortal is in bootloader mode

---

### ✅ Library Bundle
**Download from**: [circuitpython.org/libraries](https://circuitpython.org/libraries)

**File**: `adafruit-circuitpython-bundle-10.x-mpy-YYYYMMDD.zip` (match your CircuitPython version!)

**What to do**: Extract this .zip file, you'll copy libraries from inside it

---

## Step 2: Copy These Libraries to PyPortal

**Location**: `CIRCUITPY/lib/` folder

**⚠️ IMPORTANT**: PyPortal uses ESP32 SPI WiFi (NOT the built-in `wifi` module!)

**From the extracted bundle's `lib/` folder, copy exactly these items:**

```
Bundle lib folder                    Copy to CIRCUITPY/lib/
┌───────────────────────┐           ┌─────────────────────┐
│ (hundreds of files)   │           │                     │
│                       │           │                     │
│ ✅ adafruit_esp32spi/    ────────→ │ adafruit_esp32spi/     │
│    (folder)           │           │                     │
│                       │           │                     │
│ ✅ adafruit_esp32spi_socketpool.mpy → │ adafruit_esp32spi_socketpool.mpy │
│    (file - separate!) │           │                     │
│                       │           │                     │
│ ✅ adafruit_display_text/ ───────→ │ adafruit_display_text/ │
│    (folder)           │           │                     │
│                       │           │                     │
│ ✅ neopixel.mpy       ────────────→ │ neopixel.mpy        │
│    (file)             │           │                     │
│                       │           │                     │
│ (ignore all others)   │           │ (only these 4!)     │
└───────────────────────┘           └─────────────────────┘
```

### 📋 Library Checklist

Copy these **4 items** to `CIRCUITPY/lib/`:

- [ ] **`adafruit_esp32spi/`** (folder) - ESP32 WiFi driver
- [ ] **`adafruit_esp32spi_socketpool.mpy`** (file - separate from folder!) - Socket pool support
- [ ] **`adafruit_display_text/`** (folder) - Display text rendering
- [ ] **`neopixel.mpy`** (file) - RGB LED control

---

## Step 3: Copy Your Code

**From this repository**: `pyportal_firmware/code.py`

**Copy to**: Root of `CIRCUITPY` drive (not in lib folder!)

**Before copying**: Edit the WiFi credentials in `code.py`:
```python
WIFI_SSID = "YOUR_WIFI_NAME"       # Change this
WIFI_PASSWORD = "YOUR_PASSWORD"     # Change this
```

---

## Final File Structure

Your `CIRCUITPY` drive should look **exactly** like this:

```
CIRCUITPY/                          ← USB drive root
│
├── boot_out.txt                    ← Already there (CircuitPython info)
│
├── code.py                         ← YOUR file (from this repo)
│
└── lib/                            ← Folder for libraries
    │
    ├── adafruit_esp32spi/          ← FOLDER (ESP32 WiFi driver)
    │   ├── __init__.mpy
    │   ├── adafruit_esp32spi.mpy
    │   └── ...
    │
    ├── adafruit_esp32spi_socketpool.mpy ← FILE (Socket pool - separate!)
    │
    ├── adafruit_display_text/      ← FOLDER (Display text)
    │   ├── __init__.mpy
    │   ├── label.mpy
    │   └── ...
    │
    └── neopixel.mpy                ← FILE (RGB LED)
```

---

## What Changed from Original Instructions?

### ❌ OLD (Wrong for PyPortal):
- ~~adafruit_httpserver~~ - Doesn't work with ESP32 SPI
- ~~adafruit_connection_manager~~ - Not needed for ESP32 SPI
- Used `import wifi` - Only works on ESP32-S2/S3/Pico W

### ✅ NEW (Correct for PyPortal):
- **adafruit_esp32spi** - Required for PyPortal's ESP32 coprocessor
- Uses custom socket server (no extra HTTP libraries needed!)

---

## Quick Verification Checklist

### ✅ Before Starting
- [ ] PyPortal connected via USB
- [ ] Good data cable (not charge-only)
- [ ] Downloaded CircuitPython .uf2 file (9.x or 10.x)
- [ ] Downloaded library bundle .zip file (matching version!)
- [ ] Extracted library bundle

### ✅ After Installing CircuitPython
- [ ] CIRCUITPY drive appears
- [ ] `boot_out.txt` exists on CIRCUITPY
- [ ] `boot_out.txt` shows CircuitPython 9.x or 10.x
- [ ] Created `lib` folder (if doesn't exist)

### ✅ After Copying Libraries
- [ ] `lib` folder contains exactly 4 items
- [ ] Two of them are folders (adafruit_esp32spi, adafruit_display_text)
- [ ] Two of them are files (adafruit_esp32spi_socketpool.mpy, neopixel.mpy)
- [ ] **NOT** adafruit_httpserver or adafruit_requests (not needed!)

### ✅ After Copying Code
- [ ] Edited WiFi SSID and password in `code.py`
- [ ] Copied `code.py` to CIRCUITPY root (NOT in lib folder)
- [ ] PyPortal auto-restarted
- [ ] Display shows "Teams Status"

### ✅ Verification
- [ ] Display shows "Connecting to WiFi..."
- [ ] Then shows "WiFi Connected!"
- [ ] Display shows IP address
- [ ] NeoPixel LED is green (connected)
- [ ] Can access web interface at IP address

---

## Common Mistakes to Avoid

### ❌ DON'T Do This:
- ❌ Use the old library list (httpserver, connection_manager)
- ❌ Copy entire library bundle to PyPortal
- ❌ Use code that imports `wifi` module (won't work!)
- ❌ Put code.py inside lib folder
- ❌ Use 5GHz WiFi (PyPortal only supports 2.4GHz)

### ✅ DO This:
- ✅ Use the NEW library list (esp32spi + socket!)
- ✅ Copy only the 4 items listed above
- ✅ Use code that imports `adafruit_esp32spi` and `adafruit_esp32spi_socketpool`
- ✅ Put code.py in root of CIRCUITPY
- ✅ Use 2.4GHz WiFi network

---

## File Sizes (Approximate)

- `code.py` - **~12 KB**
- `adafruit_esp32spi/` folder - **~40 KB** (main WiFi driver)
- `adafruit_esp32spi_socketpool.mpy` - **~20 KB** (socket pool support)
- `adafruit_display_text/` folder - **~20 KB**
- `neopixel.mpy` - **~5 KB**

**Total library size**: ~85 KB

PyPortal has **8 MB** of flash, so this uses only ~1% 🎉

---

## Why the Change?

**PyPortal Hardware Architecture**:
```
SAMD51 Processor ←→ ESP32 WiFi Coprocessor
    (Main CPU)      (Connected via SPI)
```

The ESP32 is a **separate chip** that talks to the main processor via SPI bus. This is different from boards like ESP32-S2 where WiFi is built into the main processor.

**Result**: Must use `adafruit_esp32spi` library, NOT the built-in `wifi` module!

---

## Need More Help?

- **Installation guide**: See [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)
- **Quick start**: See [QUICKSTART.md](QUICKSTART.md)
- **Troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

**Updated code now works with CircuitPython 9.x AND 10.x!** ✨
