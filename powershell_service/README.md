# PowerShell Teams Status Service

Local Teams status monitoring scripts that read presence from Teams log files and transmit via multiple methods:
- **Bluetooth LE** (Python + RFduino) - Recommended for work PCs
- **HTTP Server** (WiFi devices like PyPortal)
- **USB Serial** (Direct USB connection)

## Quick Start - Teams BLE Transmitter (Recommended) ⭐

**For RFduino with Bluetooth LE connection**

### Prerequisites
- Python 3.8+ installed
- RFduino powered on and nearby
- Microsoft Teams installed and running

### Run the Service

```powershell
cd powershell_service
.\Start-TeamsBLE.ps1
```

The script will:
1. ✅ Check Python installation
2. ✅ Install missing dependencies (bleak, psutil)
3. ✅ Connect to RFduino via Bluetooth
4. ✅ Monitor Teams status every 5 seconds
5. ✅ Transmit status codes to RFduino

### Custom Configuration

```powershell
# Different check interval (default: 5 seconds)
.\Start-TeamsBLE.ps1 -CheckInterval 10

# Custom Python path
.\Start-TeamsBLE.ps1 -PythonPath "C:\Python39\python.exe"

# Custom Teams log path
.\Start-TeamsBLE.ps1 -TeamsLogPath "C:\Custom\Path\logs.txt"
```

### Auto-Start on Login (Optional)

**Scheduled Task (Recommended)**:
```powershell
# Install as scheduled task
.\Install-TeamsBLEService.ps1

# Check status
.\Get-TeamsBLEServiceStatus.ps1

# Uninstall
.\Uninstall-TeamsBLEService.ps1
```

**Startup Folder**:
Create shortcut in: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`

---

## Quick Start - HTTP Server (WiFi Devices)

### 1. Run the Server

```powershell
# Basic usage (recommended)
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1

# With debug output
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1 -Debug

# Custom port
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1 -Port 8081

# Custom check interval (default: 5 seconds)
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1 -CheckInterval 10
```

### 2. Test the Server

**PowerShell**:
```powershell
Invoke-WebRequest -Uri http://localhost:8080/status | ConvertFrom-Json
```

**Command Prompt**:
```cmd
curl http://localhost:8080/status
```

**Browser**:
Open: http://localhost:8080/status

### Expected Response

```json
{
  "availability": "Available",
  "activity": "Available",
  "color": "#00FF00"
}
```

## Status Values

### Availability
- `Available` - Green (#00FF00)
- `Busy` - Red (#FF0000)
- `Away` - Yellow (#FFFF00)
- `BeRightBack` - Yellow (#FFFF00)
- `DoNotDisturb` - Purple (#800080)
- `Focusing` - Purple (#800080)
- `Presenting` - Red (#FF0000)
- `InAMeeting` - Red (#FF0000)
- `Offline` - Gray (#808080)
- `Unknown` - White (#FFFFFF)

### Activity
- `Available` - Not in a call
- `InACall` - Currently in a call
- `IncomingCall` - Call ringing
- `OutgoingCall` - Making a call
- `Offline` - Teams not running

## Endpoints

### GET /status
Returns current Teams presence status

**Response**:
```json
{
  "availability": "Available",
  "activity": "Available",
  "color": "#00FF00"
}
```

### GET /health
Health check endpoint

**Response**:
```json
{
  "status": "healthy",
  "uptime": 123.45,
  "requests": 42
}
```

## Compatibility

### New Teams (Recommended)
✅ **Supported** - Works with New Teams client

**Log Location**: `%LOCALAPPDATA%\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs\`

The script automatically detects New Teams and monitors the log directory.

### Classic Teams
⚠️ **Supported but Deprecated** - Classic Teams support ends July 1, 2025

**Log Location**: `%APPDATA%\Microsoft\Teams\logs.txt`

The script will use Classic Teams logs if New Teams is not detected.

## Troubleshooting

### Port Already in Use

**Error**: "Could not start HTTP listener on port 8080"

**Solution**:
```powershell
# Check what's using port 8080
netstat -ano | findstr :8080

# Kill the process (replace PID with actual process ID)
taskkill /F /PID <PID>

# Or use a different port
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1 -Port 8081
```

### Teams Not Detected

**Error**: "Could not find Teams log directory"

**Solutions**:
1. Ensure Microsoft Teams is installed
2. Run Teams at least once (logs are created after first run)
3. Check if Teams is running: `Get-Process -Name "ms-teams"`

### No Status Updates

**Problem**: Status shows "Unknown" or doesn't update

**Solutions**:
1. Make sure Teams is running
2. Change your Teams status manually to generate log entries
3. Run with `-Debug` flag to see what's being detected:
   ```powershell
   powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1 -Debug
   ```
4. Check log file exists and is being written to:
   ```powershell
   # New Teams
   dir "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs\*.log"

   # Classic Teams
   type "$env:APPDATA\Microsoft\Teams\logs.txt"
   ```

### Permission Denied

**Error**: "Access denied" or "Unauthorized"

**Solution**: Run PowerShell as Administrator
```powershell
# Right-click PowerShell → Run as Administrator
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1
```

## Auto-Start on Login

### Option 1: Task Scheduler (Recommended)

1. Open Task Scheduler
2. Create Basic Task:
   - **Name**: Teams Status Service
   - **Trigger**: At log on
   - **Action**: Start a program
   - **Program**: `powershell.exe`
   - **Arguments**: `-ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\Repos\MSTeams-Presence-Notify\powershell_service\TeamsStatusServer.ps1"`
   - **Start in**: `D:\Repos\MSTeams-Presence-Notify\powershell_service`
3. Configure:
   - ✅ Run only when user is logged in
   - ✅ Run with highest privileges (if needed)

### Option 2: Startup Folder

Create `StartTeamsStatusService.bat`:
```batch
@echo off
cd /d D:\Repos\MSTeams-Presence-Notify\powershell_service
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File TeamsStatusServer.ps1
```

Place in: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`

### Option 3: Windows Service

For advanced users who want to run as a proper Windows service, consider using [NSSM](https://nssm.cc/) (Non-Sucking Service Manager).

## Firewall Configuration

If your PyPortal is on the same network and can't connect:

```powershell
# Run PowerShell as Administrator
netsh advfirewall firewall add rule name="Teams Presence Service" dir=in action=allow protocol=TCP localport=8080
```

## Find Your Computer's IP Address

Your PyPortal needs to connect to your computer's local IP:

```powershell
# Get IPv4 address
ipconfig | findstr /i "IPv4"

# Or more detailed
Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -like "192.168.*"}
```

Example output: `192.168.1.100`

PyPortal will connect to: `http://192.168.1.100:8080/status`

## Performance

- **CPU Usage**: < 1% (background monitoring)
- **Memory Usage**: ~50-80 MB
- **Check Interval**: 5 seconds (configurable)
- **Response Time**: < 100ms for HTTP requests

## Limitations

1. **Status Detection Delay**: 5-10 seconds after status change
2. **Log Format Dependency**: May break if Microsoft changes log format
3. **New Teams Logs**: Slightly less reliable than Classic Teams logs were
4. **Classic Teams EOL**: Classic Teams support ends July 1, 2025

## Advantages

✅ **No Azure AD Authentication** - Works without Graph API
✅ **No IT Permissions** - Runs with standard user privileges
✅ **Fast Local Detection** - No internet required
✅ **Works Offline** - Only needs local Teams installation
✅ **Simple Setup** - One PowerShell script

## Next Steps

1. ✅ **Test the server** - Run and verify status detection
2. ✅ **Get your IP address** - For PyPortal configuration
3. ✅ **Configure PyPortal** - Update `secrets.py` with server URL
4. ✅ **Test integration** - Verify PyPortal displays status

## Support

For issues specific to:
- **This script**: Open an issue in this repository
- **EBOOZ TeamsStatus**: https://github.com/EBOOZ/TeamsStatus
- **Teams logs**: Microsoft Teams support

## Credits

Based on [EBOOZ/TeamsStatus](https://github.com/EBOOZ/TeamsStatus) - Modified for PyPortal integration.
