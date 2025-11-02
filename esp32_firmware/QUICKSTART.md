# ESP32 WiFi Quick Start (5 Minutes)

Ultra-fast setup guide - get your Teams status light working in 5 minutes!

## What You Need
- ESP32 board ($8-12)
- RGB LED + 3x 220Ω resistors
- USB cable
- WiFi network access

## Step 1: Wire It Up (1 minute)

```
ESP32 GPIO 25 ──[220Ω]──> Red LED
ESP32 GPIO 26 ──[220Ω]──> Green LED
ESP32 GPIO 27 ──[220Ω]──> Blue LED
ESP32 GND     ─────────> LED Common (-)
```

## Step 2: Install Arduino IDE (1 minute)

1. Download from [arduino.cc](https://www.arduino.cc/en/software)
2. Install and launch
3. **File → Preferences** → Add to "Board Manager URLs":
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
4. **Tools → Board → Boards Manager** → Install "**esp32**"

## Step 3: Configure WiFi (30 seconds)

1. Open `TeamsStatus_WiFi.ino`
2. Change these lines:
   ```cpp
   const char* WIFI_SSID = "YourWiFiName";
   const char* WIFI_PASSWORD = "YourPassword";
   ```

## Step 4: Upload Firmware (2 minutes)

1. Connect ESP32 via USB
2. **Tools → Board** → Select your ESP32 board
3. **Tools → Port** → Select your COM port
4. Click **Upload** (→)
5. Open **Serial Monitor** (Ctrl+Shift+M)
6. Set baud to **115200**
7. **Note the IP address** shown!

## Step 5: Run PC Software (30 seconds)

**Option A - Pre-built** (recommended):
```cmd
TeamsWiFiTransmitter.exe http://teams-status.local
```

**Option B - Build it**:
```powershell
cd dotnet_wifi_service
.\Build.ps1
.\bin\Release\...\TeamsWiFiTransmitter.exe http://teams-status.local
```

## Done! 🎉

Your LED should now show your Teams status:
- 🟢 **Green** = Available
- 🔴 **Red** = Busy/Meeting/Call
- 🟡 **Yellow** = Away
- 🟣 **Purple** = Do Not Disturb

## Troubleshooting

**Can't connect to `teams-status.local`?**
Use IP address instead:
```cmd
TeamsWiFiTransmitter.exe http://192.168.1.123
```

**LED stays white?**
- Make sure Teams is running
- Check wiring (common cathode vs anode)
- Try changing your status in Teams

**WiFi won't connect?**
- Double-check SSID and password
- Use 2.4GHz network (ESP32 doesn't support 5GHz)
- Move closer to router

## Web Interface

Visit `http://teams-status.local` in your browser to see:
- Current status
- Connection info
- Real-time LED preview

---

For detailed setup and troubleshooting, see [README.md](README.md)
