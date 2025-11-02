# RFduino Teams Status Indicator

Displays Microsoft Teams presence status on an RGB LED via Bluetooth Low Energy.

## Hardware Requirements

### Option 1: RFduino Shields (Plug-and-Play) ⭐
- **RFD22121** - USB Shield (provides power and programming)
- **RFD22102** - RFduino BLE module
- **RFD22122** - RGB Shield (built-in LED, no wiring needed!)

**Setup**: Simply stack the shields together - that's it! No wiring required.

### Option 2: RFduino Board + Custom LED
- **RFduino board** (or compatible nRF51822 board)
- **RGB LED** (Common Cathode)
- **3x 220Ω resistors** (for LED protection)
- **Battery** (CR2032 coin cell or LiPo for portable use)

## LED Wiring

### If Using RFD22122 RGB Shield
**No wiring needed!** The RGB shield has everything built-in. Just stack:
1. RFD22121 (USB Shield) - bottom
2. RFD22102 (RFduino module) - middle
3. RFD22122 (RGB Shield) - top

Plug in USB cable and you're ready to program.

### If Using Custom RGB LED
```
RFduino Pin 2 (Red)   -> 220Ω resistor -> LED Red anode
RFduino Pin 3 (Green) -> 220Ω resistor -> LED Green anode
RFduino Pin 4 (Blue)  -> 220Ω resistor -> LED Blue anode
LED Common Cathode    -> GND
```

## Status Colors

| Teams Status      | LED Color  |
|-------------------|------------|
| Available         | 🟢 Green   |
| Busy              | 🔴 Red     |
| In a Meeting      | 🔴 Red     |
| In a Call         | 🔴 Red     |
| Presenting        | 🔴 Red     |
| Away              | 🟡 Yellow  |
| Be Right Back     | 🟡 Yellow  |
| Do Not Disturb    | 🟣 Purple  |
| Focusing          | 🟣 Purple  |
| Offline           | ⚫ Dim     |
| Unknown           | ⚪ White   |

## Software Setup

### 1. Install Arduino IDE

Download and install Arduino IDE 1.8.x from:
https://www.arduino.cc/en/software

### 2. Install RFduino Board Support

**Method 1: Manual Board Manager URL** (if available)

1. Open Arduino IDE
2. Go to **File → Preferences**
3. In "Additional Board Manager URLs", add:
   ```
   http://rfduino.com/package_rfduino_index.json
   ```
4. Click **OK**
5. Go to **Tools → Board → Boards Manager**
6. Search for "RFduino"
7. Click **Install**

**Method 2: Manual Installation** (if URL is down)

1. Download RFduino package from: https://github.com/RFduino/RFduino
2. Extract to Arduino hardware folder:
   - Windows: `C:\Users\<username>\Documents\Arduino\hardware\RFduino\`
   - Mac: `~/Documents/Arduino/hardware/RFduino/`
3. Restart Arduino IDE

### 3. Install RFduinoBLE Library

The RFduinoBLE library should be included with the board support. If not:

1. Download from: https://github.com/RFduino/RFduino/tree/master/libraries/RFduinoBLE
2. Place in Arduino libraries folder:
   - Windows: `C:\Users\<username>\Documents\Arduino\libraries\RFduinoBLE\`

### 4. Open and Upload Firmware

1. Connect your RFduino shield stack via USB
2. In Arduino IDE:
   - **File → Open** → Select `TeamsStatus.ino`
   - **Tools → Board** → Select **RFduino**
   - **Tools → Port** → Select the COM port (e.g., COM3)
3. Click **Upload** button (→)
4. Wait for "Done uploading" message
5. LED should do a white fade-in animation

### 4. Install Python Dependencies

On your Windows PC:

```powershell
cd ..\computer_service
pip install bleak psutil asyncio
```

### 5. Run BLE Transmitter

```powershell
python teams_ble_transmitter.py
```

You should see:
```
Scanning for RFduino...
✓ Found RFduino: RFduino (XX:XX:XX:XX:XX:XX)
✓ Connected to RFduino

Monitoring Teams status...
[14:30:45] Sent: Away (code: 2)
```

## Troubleshooting

### Arduino IDE Issues

**Board Manager URL Not Working**
- The official RFduino site may be offline
- Use manual installation method (Method 2 above)
- Download board files from: https://github.com/RFduino/RFduino

**RFduino Not in Board List**
1. Restart Arduino IDE after installing board support
2. Check `File → Preferences → Additional Boards Manager URLs`
3. Try manual installation to Arduino hardware folder

**COM Port Not Showing**
1. Install RFduino USB drivers from: https://github.com/RFduino/RFduino/tree/master/drivers
2. Check Device Manager for "RFduino" or "USB Serial Device"
3. Try different USB cable (must be data cable, not charge-only)

**Upload Failed Error**
1. Select correct board: **Tools → Board → RFduino**
2. Select correct port: **Tools → Port → COM#**
3. Press and hold **RESET** button, then click **Upload**
4. Release reset when "Uploading..." appears

### BLE Connection Issues

**RFduino Not Found by Python Script**
1. Ensure firmware uploaded successfully (LED fades in white)
2. Check Bluetooth is enabled on Windows PC
3. Verify RFduino is powered on
4. Try resetting RFduino (power cycle)
5. Check device name in firmware matches Python script

**Connection Drops**
1. Move RFduino closer to PC (within 10 feet)
2. Remove interference sources (WiFi routers, microwaves)
3. Check battery level if running on battery

### LED Issues

**LED Not Lighting (Shield Stack)**
- Shields should be firmly seated together
- RGB Shield LED is on the top of the stack
- Try running example sketches first to test LED

**Wrong Colors Displayed**
- Verify pin definitions in code match RFD22122 (pins 2,3,4)
- Check shield is oriented correctly (not backwards)

### Python Issues

**Module Not Found Error**
```powershell
pip install --upgrade bleak psutil
```

**Python Version Error**
- Requires Python 3.8 or newer
- Check version: `python --version`

**Teams Status Not Updating**
- Ensure Teams is running
- Check Teams log path in Python script
- Try closing and reopening Teams

## Power Optimization

For battery operation, modify `TeamsStatus.ino`:

```cpp
// In setup(), after RFduinoBLE.begin():
RFduino_ULPDelay(INFINITE);  // Enable ultra-low power mode
```

This extends battery life significantly when idle.

## Customization

### Change Device Name

In `TeamsStatus.ino`, in the `setup()` function:
```cpp
RFduinoBLE.deviceName = "MyTeamsLight";
```

### Adjust LED Brightness

In `setColor()` function, scale RGB values:
```cpp
void setColor(int red, int green, int blue) {
    // 50% brightness
    analogWrite(RED_PIN, red / 2);
    analogWrite(GREEN_PIN, green / 2);
    analogWrite(BLUE_PIN, blue / 2);
}
```

### Change Check Interval

In `teams_ble_transmitter.py`, line 17:
```python
CHECK_INTERVAL = 10  # Check every 10 seconds instead of 5
```

## Architecture

```
Work PC (Windows)
    ↓
teams_ble_transmitter.py
    ↓ Bluetooth Low Energy
RFduino
    ↓ GPIO pins (PWM)
RGB LED
```

## License

MIT - Feel free to modify and distribute
