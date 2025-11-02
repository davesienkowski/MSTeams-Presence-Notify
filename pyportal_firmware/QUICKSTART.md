# PyPortal Quick Start (10 Minutes)

Get your Teams status monitor working in just 10 minutes with **zero wiring**!

## What You Need
- Adafruit PyPortal (any variant: PyPortal, Titano, or Pynt)
- USB cable (included with PyPortal)
- WiFi network access

## Step-by-Step Setup

### 1️⃣ Install CircuitPython (3 min)

**Download firmware**:
- Go to [circuitpython.org/board/pyportal](https://circuitpython.org/board/pyportal/)
- Download latest **9.x.x** `.uf2` file

**Install**:
1. Plug PyPortal into computer
2. **Double-click** reset button on back
3. Drag `.uf2` file onto `PORTALBOOT` drive
4. PyPortal reboots → now shows as `CIRCUITPY` drive ✅

### 2️⃣ Install Libraries (2 min)

**Download bundle**:
- Go to [circuitpython.org/libraries](https://circuitpython.org/libraries)
- Download **9.x Bundle** (match your CircuitPython version)
- Unzip

**Copy to PyPortal**:
- On `CIRCUITPY` drive, create `lib` folder
- From bundle's `lib` folder, copy these to `CIRCUITPY/lib/`:
  - `adafruit_httpserver/` (folder)
  - `adafruit_display_text/` (folder)
  - `neopixel.mpy` (file)
  - `adafruit_connection_manager/` (folder)

### 3️⃣ Configure WiFi (1 min)

1. Open `code.py` (from this repo) in text editor
2. Find:
   ```python
   WIFI_SSID = "YOUR_WIFI_SSID"
   WIFI_PASSWORD = "YOUR_WIFI_PASSWORD"
   ```
3. Change to your WiFi:
   ```python
   WIFI_SSID = "CompanyWiFi"
   WIFI_PASSWORD = "yourpassword"
   ```

### 4️⃣ Upload Code (1 min)

1. Copy `code.py` from this repo
2. Paste onto `CIRCUITPY` drive
3. PyPortal auto-restarts ✅

### 5️⃣ Verify (1 min)

**PyPortal display shows**:
- "Teams Status" (title)
- "WiFi Connected!" message
- IP address at bottom (write it down!)

**Test web interface**:
- Open browser
- Visit `http://teams-status.local`
- See the status page! 🎉

### 6️⃣ Run PC Software (2 min)

```cmd
TeamsWiFiTransmitter.exe http://teams-status.local
```

## Done! 🎉

Your PyPortal now shows:
- **Display**: Large status text with color background
- **NeoPixel**: LED glowing with status color
- **Web UI**: Monitor from any browser

## Status Colors

- 🟢 Green = Available
- 🔴 Red = Busy/Meeting/Call
- 🟡 Yellow = Away
- 🟣 Purple = Do Not Disturb
- ⚫ Gray = Offline
- ⚪ White = Unknown

## Troubleshooting

**WiFi won't connect?**
- Check SSID/password
- Use 2.4GHz network (not 5GHz)
- Move closer to router

**Import errors?**
- Copy all 4 libraries to `lib` folder
- Match CircuitPython and bundle versions

**Can't find `teams-status.local`?**
- Use IP address shown on PyPortal display
- Format: `http://192.168.1.123`

**PC transmitter won't connect?**
- Check firewall settings
- Verify both on same network
- Try IP instead of `.local` hostname

## What's Next?

See [README.md](README.md) for:
- Advanced configuration
- Custom colors
- Debugging tips
- Enhancement ideas

---

**Zero wiring. Just plug and play!** ✨
