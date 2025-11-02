# RFduino Arduino IDE Setup Guide

**Updated**: January 2025

## ⚠️ Important Notice

RFduino was acquired by AMS Group and the official site (rfduino.com) is offline. The board manager URL may not work, so manual installation is recommended.

---

## Method 1: Board Manager Installation (Try First)

### Step 1: Install Arduino IDE
Download Arduino IDE 1.8.x from: https://www.arduino.cc/en/software

### Step 2: Add Board Manager URL

1. Open Arduino IDE
2. Go to **File → Preferences**
3. In "Additional Board Manager URLs" field, add:
   ```
   http://rfduino.com/package_rfduino166_index.json
   ```
4. Click **OK**

### Step 3: Install RFduino Board

1. Go to **Tools → Board → Boards Manager**
2. Search for "RFduino"
3. Click **Install** on the RFduino package
4. Wait for installation to complete

### Step 4: Verify Installation

Check if **RFduino** appears in **Tools → Board** menu.

**If this works, skip to "Upload Firmware" section below.**

---

## Method 2: Manual Installation (Recommended)

Since the board manager URL is likely broken, use this method:

### Step 1: Download RFduino Files

**Option A: Download ZIP**
1. Go to: https://github.com/RFduino/RFduino
2. Click **Code** → **Download ZIP**
3. Extract the ZIP file

**Option B: Git Clone**
```bash
git clone https://github.com/RFduino/RFduino.git
```

### Step 2: Locate Arduino Hardware Folder

**Windows:**
- Arduino Sketchbook: `C:\Users\<YourUsername>\Documents\Arduino\hardware\`
- If `hardware` folder doesn't exist, create it

**Mac:**
- `/Applications/Arduino.app/Contents/Java/hardware/`
- Or: `~/Documents/Arduino/hardware/`

**Linux:**
- `~/Arduino/hardware/`

### Step 3: Install RFduino

1. Create a folder: `hardware\RFduino\`
2. Copy the contents of the downloaded RFduino repository into this folder

Your structure should look like:
```
Arduino/
└── hardware/
    └── RFduino/
        ├── libraries/
        │   └── RFduinoBLE/
        ├── variants/
        ├── boards.txt
        ├── platform.txt
        └── ...
```

### Step 4: Restart Arduino IDE

Close and reopen Arduino IDE completely.

### Step 5: Verify Installation

1. Go to **Tools → Board**
2. You should see **RFduino** in the list

---

## Install FTDI Drivers (Required for USB Shield)

If your COM port doesn't show up:

**Windows:**
1. Download FTDI VCP drivers from: https://ftdichip.com/drivers/vcp-drivers/
2. Install the Windows driver
3. Restart your computer

**Mac:**
1. Download Mac VCP drivers from FTDI
2. Install and restart

**Linux:**
- Drivers are usually built-in
- Add yourself to dialout group:
  ```bash
  sudo usermod -aG dialout $USER
  ```
- Log out and back in

---

## Upload Firmware to RFduino

### Step 1: Connect Hardware

Stack your shields in order:
1. **Bottom**: RFD22121 (USB Shield)
2. **Middle**: RFD22102 (RFduino BLE module)
3. **Top**: RFD22122 (RGB Shield)

Connect USB cable to your PC.

### Step 2: Select Board and Port

1. **Tools → Board** → Select **RFduino**
2. **Tools → Port** → Select your COM port (e.g., COM3)
   - Look for "USB Serial Port" or "RFduino"

### Step 3: Open the Sketch

1. **File → Open**
2. Navigate to: `d:\Repos\MSTeams-Presence-Notify\rfduino_firmware\TeamsStatus.ino`
3. Click **Open**

### Step 4: Upload

1. Click the **Upload** button (→) in the toolbar
2. Wait for "Done uploading" message
3. **Success indicator**: LED should fade in white

---

## Troubleshooting

### Board Not in List

**Problem**: RFduino doesn't appear in Tools → Board menu

**Solutions**:
1. Restart Arduino IDE completely
2. Verify hardware folder location is correct
3. Check that `boards.txt` exists in the RFduino folder
4. Re-download and reinstall from GitHub

### COM Port Not Showing

**Problem**: No COM ports appear in Tools → Port menu

**Solutions**:
1. Install FTDI drivers (see above)
2. Check Device Manager (Windows):
   - Look for "Ports (COM & LPT)"
   - Should see "USB Serial Port (COM#)"
3. Try a different USB cable (must be data cable, not charge-only)
4. Try a different USB port on your computer

### Upload Failed

**Problem**: "avrdude: stk500_getsync() not in sync" or similar error

**Solutions**:
1. Verify correct board is selected: **Tools → Board → RFduino**
2. Verify correct COM port is selected
3. Try the **reset button method**:
   - Press and hold the **RESET** button on USB shield
   - Click **Upload** in Arduino IDE
   - Release reset button when you see "Uploading..." message
4. Check that shields are firmly seated together

### Compilation Errors

**Problem**: Errors about missing RFduinoBLE.h or similar

**Solutions**:
1. Verify RFduinoBLE library is in:
   - `Arduino\hardware\RFduino\libraries\RFduinoBLE\`
2. If missing, download from: https://github.com/RFduino/RFduino/tree/master/libraries/RFduinoBLE
3. Restart Arduino IDE

### LED Not Working After Upload

**Problem**: Upload succeeds but LED doesn't light

**Solutions**:
1. Check that RGB shield (RFD22122) is on top
2. Verify shields are properly seated (not loose)
3. Try uploading a simple blink sketch first to test LED:
   ```cpp
   void setup() {
     pinMode(2, OUTPUT); // Red LED
   }
   void loop() {
     digitalWrite(2, HIGH);
     delay(1000);
     digitalWrite(2, LOW);
     delay(1000);
   }
   ```

---

## Next Steps

Once firmware is uploaded successfully:

1. **Install Python dependencies**:
   ```powershell
   cd d:\Repos\MSTeams-Presence-Notify\computer_service
   pip install bleak psutil
   ```

2. **Run the BLE transmitter**:
   ```powershell
   python teams_ble_transmitter.py
   ```

3. **Expected behavior**:
   - Python script finds and connects to RFduino
   - LED changes color based on Teams status
   - 🟢 Green = Available
   - 🔴 Red = Busy/Meeting/Call
   - 🟡 Yellow = Away
   - 🟣 Purple = Do Not Disturb
   - ⚫ Dim = Offline

---

## Additional Resources

- **RFduino GitHub**: https://github.com/RFduino/RFduino
- **RFduinoBLE Library**: https://github.com/RFduino/RFduino/tree/master/libraries/RFduinoBLE
- **FTDI Drivers**: https://ftdichip.com/drivers/vcp-drivers/
- **Arduino IDE**: https://www.arduino.cc/en/software

---

## Alternative: Use Arduino IDE 1.6.x

If you're having issues with Arduino IDE 1.8.x, try using Arduino 1.6.6 (the original supported version):

1. Download Arduino 1.6.6 from Arduino's archive
2. Install RFduino using board manager (URL might work better with older IDE)
3. Follow the same upload steps

However, Arduino 1.8.x should work with manual installation method.
