# Teams BLE Transmitter (.NET Version)

Native C# implementation for monitoring Microsoft Teams status and transmitting via Bluetooth LE to RFduino.

## Advantages over Python Version

- No Python installation required
- Native Windows Bluetooth LE support
- Lower memory footprint (~20MB vs ~50MB)
- Faster startup time
- Single .exe deployment (no dependencies)
- Better suited for corporate environments

## Prerequisites

- Windows 10 version 1809 or later (for Bluetooth LE support)
- .NET 6.0 Runtime (or SDK for building)
- Bluetooth adapter
- RFduino powered on and nearby
- Microsoft Teams installed

## Quick Start (Pre-built)

If you have a pre-built `TeamsBLETransmitter.exe`:

```cmd
TeamsBLETransmitter.exe
```

That's it! The application will:
1. Find and connect to RFduino via Bluetooth
2. Monitor Teams log files
3. Transmit status changes to RFduino

## Building from Source

### Option 1: Using dotnet CLI (Recommended)

```powershell
cd dotnet_service

# Build
dotnet build

# Run directly
dotnet run

# Or publish as single .exe
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true

# The .exe will be in:
# bin\Release\net6.0-windows10.0.19041.0\win-x64\publish\TeamsBLETransmitter.exe
```

### Option 2: Using Visual Studio

1. Open `TeamsBLETransmitter.csproj` in Visual Studio 2022
2. Build > Build Solution (Ctrl+Shift+B)
3. Run > Start Without Debugging (Ctrl+F5)

## Command Line Options

```
TeamsBLETransmitter.exe [options]

Options:
  -i, --interval <seconds>     Check interval (default: 5)
  -l, --log-path <path>        Teams log file/directory path
  -d, --device-name <name>     RFduino device name (default: RFduino)
  -h, --help                   Show help
```

### Examples

```powershell
# Default settings (5 second interval)
TeamsBLETransmitter.exe

# Check every 10 seconds
TeamsBLETransmitter.exe -i 10

# Custom device name
TeamsBLETransmitter.exe -d "MyRFduino"

# Custom Teams log path
TeamsBLETransmitter.exe -l "C:\Custom\Path\logs.txt"
```

## Auto-Start on Login

### Option 1: Task Scheduler (Recommended)

1. Open Task Scheduler
2. Create Basic Task:
   - **Name**: Teams BLE Transmitter
   - **Trigger**: At log on
   - **Action**: Start a program
   - **Program**: Full path to `TeamsBLETransmitter.exe`
   - **Start in**: Directory containing the .exe
3. Configure:
   - Run only when user is logged in
   - Run with highest privileges (if needed)

### Option 2: Startup Folder

1. Create shortcut to `TeamsBLETransmitter.exe`
2. Copy shortcut to: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`

### Option 3: Windows Service

For running as a background service, see [WINDOWS_SERVICE.md](WINDOWS_SERVICE.md) (coming soon).

## Troubleshooting

### "No Bluetooth adapter found"

**Check Bluetooth status**:
```powershell
Get-PnpDevice -Class Bluetooth
```

**Solutions**:
- Enable Bluetooth in Windows Settings
- Update Bluetooth drivers
- Restart Bluetooth service: `Restart-Service bthserv`

### "RFduino not found"

**Solutions**:
1. Ensure RFduino is powered on
2. Check battery/power source
3. Move RFduino closer to PC
4. Check device name matches: `-d "YourDeviceName"`
5. Pair RFduino in Windows Bluetooth settings first (optional)

### "Failed to discover GATT services"

**Solutions**:
- Unpair and re-pair the RFduino
- Restart Bluetooth adapter
- Restart application
- Check RFduino firmware is running

### "Access denied" or "Insufficient permissions"

**Solutions**:
- Run as Administrator (right-click > Run as administrator)
- Check Windows Privacy settings > Bluetooth (allow app access)

## System Requirements

- **OS**: Windows 10 version 1809+ or Windows 11
- **RAM**: 50MB minimum
- **CPU**: Minimal (< 1% usage)
- **.NET**: .NET 6.0 Runtime or later
- **Bluetooth**: Bluetooth 4.0+ adapter

## Status Codes

| Status | Code | Display |
|--------|------|---------|
| Available | 1 | Green |
| Busy | 2 | Red |
| Do Not Disturb | 3 | Purple |
| Away | 4 | Yellow |
| Be Right Back | 5 | Yellow |
| Focusing | 6 | Purple |
| In a Meeting | 7 | Red |
| Presenting | 8 | Red |
| Offline | 9 | Gray |

## Performance

- **Memory**: ~20MB (vs ~50MB Python)
- **CPU**: < 0.5% average
- **Startup**: < 2 seconds
- **BLE Latency**: < 100ms

## Comparison: .NET vs Python

| Feature | .NET | Python |
|---------|------|--------|
| Installation | .NET Runtime (often pre-installed) | Python + pip packages |
| Deployment | Single .exe | Multiple files + interpreter |
| Memory | ~20MB | ~50MB |
| Startup | < 2s | ~5s |
| Dependencies | None (self-contained) | bleak, psutil |
| Corporate Friendly | High | Medium |

## Development

### Project Structure

```
dotnet_service/
├── TeamsBLETransmitter.csproj    # Project file
├── Program.cs                     # Entry point
├── Configuration.cs               # Config & argument parsing
├── TeamsStatus.cs                 # Status enum & helpers
├── TeamsLogMonitor.cs            # Teams log file parser
├── RFduinoConnector.cs           # Bluetooth LE connection
├── TeamsStatusService.cs         # Main service logic
└── README.md                      # This file
```

### Key Classes

- **Program**: Entry point and orchestration
- **Configuration**: Command-line arguments and settings
- **TeamsLogMonitor**: Parses Teams log files for status
- **RFduinoConnector**: Bluetooth LE communication with RFduino
- **TeamsStatusService**: Main service loop coordinating monitoring and transmission

### Technologies Used

- **Target**: .NET 6.0 (Windows 10.0.19041.0)
- **Bluetooth**: Windows.Devices.Bluetooth APIs
- **Deployment**: Self-contained single-file publish

## License

MIT License - See LICENSE file for details

## Credits

- Based on Python implementation in this repository
- Inspired by [EBOOZ/TeamsStatus](https://github.com/EBOOZ/TeamsStatus)
- RFduino Bluetooth integration

## Support

For issues:
1. Check Troubleshooting section above
2. Verify RFduino firmware is correct
3. Test with Python version first (if available)
4. Open GitHub issue with logs
