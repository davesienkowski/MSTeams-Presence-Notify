# MS Teams Presence Notification Light

Visual indicator for Microsoft Teams presence status supporting multiple hardware platforms. Displays your Teams availability status (Available, Busy, Away, Do Not Disturb, etc.) with color-coded LEDs or displays.

## Project Overview

This solution provides **four different approaches** to display Teams status:

### 1. **RFduino + BLE** (Recommended for Work PCs) ⭐
- **Hardware**: RFduino board with RGB LED
- **Connection**: Bluetooth Low Energy (no network required)
- **Best for**: Corporate environments with network restrictions
- **Power**: Battery powered, portable

### 2. **Raspberry Pi + Unicorn HAT** (Home/Desk Display) 🌈
- **Hardware**: Raspberry Pi 3 B+ with Pimoroni Unicorn HAT (8x8 RGB LED matrix)
- **Connection**: WiFi/Ethernet HTTP
- **Best for**: Desk displays with animated status indicators
- **Power**: 5V 2.5A+ power supply
- **Features**: 64 addressable LEDs with animations

### 3. **PowerShell HTTP Server** (WiFi Devices)
- **Hardware**: PyPortal, ESP32, or any WiFi device
- **Connection**: HTTP over local network
- **Best for**: Home networks with open access
- **Power**: USB powered

### 4. **PowerShell Serial Server** (USB Connection)
- **Hardware**: Any microcontroller with USB serial
- **Connection**: Direct USB cable
- **Best for**: When Bluetooth and network are unavailable
- **Power**: USB powered

## Features

- **Real-time Teams status** from log file monitoring (no Graph API required)
- **Multiple connection methods**: Bluetooth, WiFi, USB Serial
- **Color-coded status indicators** matching Teams colors
- **Low power consumption** (especially BLE battery mode)
- **No admin rights required** (log parsing method)
- **Works on restricted networks** (BLE bypasses firewall)

## Status Color Mapping

| Status | Color | Description |
|--------|-------|-------------|
| Available | Green | You're available |
| Busy | Red | You're busy |
| Away | Yellow | You're away |
| BeRightBack | Yellow | Be right back |
| DoNotDisturb | Purple | Do not disturb |
| InAMeeting | Red | In a meeting |
| InACall | Red | In a call |
| Offline | Gray | Offline |
| Unknown | White | Status unknown |

## Hardware Options

**Not sure which hardware to choose?** See [HARDWARE_COMPARISON.md](HARDWARE_COMPARISON.md) for detailed comparison of all options.

### Option 1: RFduino (Recommended for Work)
- [RFduino board](https://github.com/RFduino/RFduino) or compatible nRF51822
- RGB LED (Common Cathode) + 3x 220Ω resistors
- CR2032 coin cell or small LiPo battery

### Option 2: Raspberry Pi + Unicorn HAT (Desk Display)
- [Raspberry Pi 3 Model B+](https://www.raspberrypi.com/products/raspberry-pi-3-model-b-plus/) (or Pi 2/4/Zero W)
- [Pimoroni Unicorn HAT](https://shop.pimoroni.com/products/unicorn-hat) (8x8 WS2812B LEDs)
- 5V 2.5A+ power supply
- MicroSD card with Raspberry Pi OS

### Option 3: WiFi Devices
- [Adafruit PyPortal](https://www.adafruit.com/product/4116), ESP32, or similar
- USB cable for power
- WiFi network access

### Option 4: USB Serial
- Any microcontroller with USB serial (Arduino, ESP32, etc.)
- LED or display module
- USB cable to PC

## Software Requirements

- **Windows PC** with Microsoft Teams (New Teams or Classic)
- **PowerShell 5.1+** (built into Windows)
- **Python 3.8+** OR **.NET 6.0 Runtime** (for BLE transmitter - choose one)
- **Arduino IDE 1.8.x** (for RFduino firmware)
- **Raspberry Pi OS** (for Raspberry Pi + Unicorn HAT)

## Project Structure

```
MSTeams-Presence-Notify/
├── powershell_service/           # PowerShell servers (no Graph API)
│   ├── TeamsStatusServer.ps1    # HTTP server for WiFi devices
│   ├── TeamsStatusSerial.ps1    # USB serial server
│   └── Start-TeamsBLE.ps1       # Python BLE launcher
├── computer_service/             # Python BLE transmitter
│   ├── teams_ble_transmitter.py # BLE broadcast to RFduino
│   └── requirements.txt         # Python dependencies
├── dotnet_service/               # C# .NET BLE transmitter (alternative)
│   ├── TeamsBLETransmitter.csproj # Project file
│   ├── Program.cs               # Main application
│   ├── Build.ps1                # Build script
│   └── README.md                # .NET documentation
├── rfduino_firmware/             # RFduino Arduino firmware
│   ├── src/main.cpp             # Main firmware code
│   ├── platformio.ini           # PlatformIO configuration
│   └── README.md                # Hardware setup guide
├── raspberry_pi_unicorn/         # Raspberry Pi + Unicorn HAT
│   ├── teams_status_unicorn.py  # Python display application
│   ├── requirements.txt         # Python dependencies
│   └── RASPBERRY_PI_SETUP.md    # Complete setup guide
├── docs/                         # Documentation
├── RASPBERRY_PI_SETUP.md        # Raspberry Pi setup instructions
└── README.md                    # This file
```

## Quick Start Guides

### Method 1: RFduino + Bluetooth ⭐ (Best for Work PCs)

**Step 1: Install Arduino IDE and RFduino Support**
1. Download Arduino IDE 1.8.x from https://www.arduino.cc/en/software
2. Add board manager URL: `http://rfduino.com/package_rfduino_index.json`
3. Install RFduino board via Tools → Board → Boards Manager

**Step 2: Upload RFduino Firmware**
1. Stack your shields (USB Shield + RFduino + RGB Shield)
2. Connect via USB
3. Open `rfduino_firmware/TeamsStatus.ino` in Arduino IDE
4. Select **Tools → Board → RFduino**
5. Select **Tools → Port → COM#** (your device)
6. Click **Upload** (→)
7. LED should fade in white on success

**Step 3A: Python BLE Transmitter**
```powershell
cd computer_service
pip install bleak psutil
python teams_ble_transmitter.py
```

**Step 3B: .NET BLE Transmitter (Alternative - No Python Required)**
```powershell
cd dotnet_service

# Build from source
dotnet publish -c Release

# Or download pre-built TeamsBLETransmitter.exe and run:
TeamsBLETransmitter.exe
```

See [dotnet_service/README.md](dotnet_service/README.md) for .NET version details and [rfduino_firmware/README.md](rfduino_firmware/README.md) for RFduino setup.

---

### Method 2: Raspberry Pi + Unicorn HAT 🌈 (Desk Display)

**Step 1: Hardware Setup**
1. Mount Unicorn HAT on Raspberry Pi GPIO pins (power off first!)
2. Connect 5V 2.5A+ power supply
3. Boot Raspberry Pi with network connection

**Step 2: Install Unicorn HAT Software**
```bash
# One-line installer (recommended)
curl -sS https://get.pimoroni.com/unicornhat | bash

# Or manual installation
sudo apt-get update
sudo pip3 install unicornhat requests
```

**Step 3: Start PowerShell Server on Windows PC**
```powershell
cd powershell_service
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1
```

**Step 4: Configure and Run Raspberry Pi**
```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
nano teams_status_unicorn.py  # Edit SERVER_URL with your PC's IP
sudo python3 teams_status_unicorn.py
```

See [RASPBERRY_PI_SETUP.md](RASPBERRY_PI_SETUP.md) for complete setup guide including:
- Detailed hardware assembly
- Multiple animation modes (pulse, ripple, gradient, spinner)
- Auto-start on boot configuration
- Troubleshooting and customization

---

### Method 3: HTTP Server (WiFi Devices)

**Step 1: Start PowerShell Server**
```powershell
cd powershell_service
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1
```

**Step 2: Add Firewall Rule** (as Administrator)
```powershell
New-NetFirewallRule -DisplayName "Teams Status Server" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow -Profile Private
```

**Step 3: Configure Your Device**
- Connect to `http://<your-pc-ip>:8080/status`
- Device receives JSON: `{"availability":"Away","activity":"Away","color":"#FFFF00"}`

---

### Method 4: USB Serial (Direct Connection)

**Step 1: Find COM Port**
```powershell
[System.IO.Ports.SerialPort]::GetPortNames()
```

**Step 2: Start Serial Server**
```powershell
cd powershell_service
powershell -ExecutionPolicy Bypass -File TeamsStatusSerial.ps1 -ComPort COM3
```

**Step 3: Program Your Microcontroller**
- Read JSON from serial port at 115200 baud
- Parse status and control LED accordingly

## Architecture

### Method 1: BLE (RFduino)
```
MS Teams → Teams Logs → PowerShell/Python Parser → BLE → RFduino → RGB LED
```

### Method 2: HTTP (Raspberry Pi + Unicorn HAT)
```
MS Teams → Teams Logs → PowerShell Server (Port 8080) → WiFi → Raspberry Pi → 8x8 LED Matrix
```

### Method 3: HTTP (WiFi Devices)
```
MS Teams → Teams Logs → PowerShell Server (Port 8080) → WiFi → Device → Display
```

### Method 4: Serial (USB)
```
MS Teams → Teams Logs → PowerShell Server → USB Serial → Microcontroller → LED
```

**Key Advantage**: Direct log parsing requires **no Microsoft Graph API**, **no Azure AD**, and **no admin permissions**.

## How It Works

1. **Teams writes status to local log files** (continuously updated)
2. **PowerShell/Python monitors these logs** every 5 seconds
3. **Status is parsed using regex patterns** (SetBadge, NotifyCall, etc.)
4. **Status transmitted** via BLE/HTTP/Serial to display device
5. **LED shows color-coded status** matching Teams

## References

- [RFduinoBLE Library](https://github.com/RFduino/RFduino)
- [PlatformIO Documentation](https://docs.platformio.org/)
- [Bleak BLE Library](https://github.com/hbldh/bleak)
- Based on log parsing technique from:
  - [EBOOZ/TeamsStatus](https://github.com/EBOOZ/TeamsStatus)
- Inspired by:
  - [Teams-Presence](https://github.com/maxi07/Teams-Presence)
  - [PresenceLight](https://github.com/isaacrlevin/PresenceLight)

## License

MIT License - See LICENSE file for details

## Contributing

Contributions welcome! Please open an issue or submit a pull request.

## Support

For issues and questions, please open an GitHub issue.
