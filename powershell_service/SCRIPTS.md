# PowerShell Service Scripts Reference

Quick reference for all PowerShell scripts in this directory.

## Teams BLE Transmitter Scripts (Python-based)

These scripts manage the Python-based Bluetooth LE transmitter for RFduino.

### Start-TeamsBLE.ps1

**Purpose**: Manual launcher for Teams BLE transmitter

**Usage**:
```powershell
.\Start-TeamsBLE.ps1 [options]
```

**Options**:
- `-PythonPath <path>` - Custom Python executable path (default: "python")
- `-CheckInterval <seconds>` - Status check interval (default: 5)
- `-TeamsLogPath <path>` - Custom Teams log path (default: auto-detect)

**Examples**:
```powershell
# Basic usage
.\Start-TeamsBLE.ps1

# Custom interval
.\Start-TeamsBLE.ps1 -CheckInterval 10

# Custom Python
.\Start-TeamsBLE.ps1 -PythonPath "C:\Python39\python.exe"

# All options
.\Start-TeamsBLE.ps1 -PythonPath "python3" -CheckInterval 3 -TeamsLogPath "C:\Custom\logs.txt"
```

**Features**:
- ✅ Automatic Python version check
- ✅ Automatic dependency installation (bleak, psutil)
- ✅ Script path validation
- ✅ Clear error messages
- ✅ PowerShell 5.1 compatible

---

### Install-TeamsBLEService.ps1

**Purpose**: Install Teams BLE transmitter as Windows scheduled task (auto-start on login)

**Usage**:
```powershell
.\Install-TeamsBLEService.ps1 [options]
```

**Options**:
- Same as Start-TeamsBLE.ps1

**Features**:
- ✅ Creates scheduled task "MSTeamsPresenceBLE"
- ✅ Auto-start on user login
- ✅ Auto-restart on failure (3 attempts, 1-minute interval)
- ✅ Runs in background (hidden window)
- ✅ No admin rights required
- ✅ Works with battery/AC power

**Task Configuration**:
- **Name**: MSTeamsPresenceBLE
- **Trigger**: At user logon
- **User**: Current user (no admin)
- **Window**: Hidden
- **Restart**: 3 attempts with 1-minute intervals

**Examples**:
```powershell
# Basic installation
.\Install-TeamsBLEService.ps1

# With custom interval
.\Install-TeamsBLEService.ps1 -CheckInterval 10

# Start immediately after install
.\Install-TeamsBLEService.ps1
# Answer "Y" when prompted to start
```

---

### Get-TeamsBLEServiceStatus.ps1

**Purpose**: Check status and health of Teams BLE service

**Usage**:
```powershell
.\Get-TeamsBLEServiceStatus.ps1
```

**Shows**:
- ✅ Scheduled task status (Ready/Running/Disabled)
- ✅ Last run time and result
- ✅ Next run time
- ✅ Python process status (PID, CPU, Memory)
- ✅ Bluetooth adapter status
- ✅ Management commands

**Example Output**:
```
========================================
Teams BLE Service Status
========================================

Service Status:
  Task Name: MSTeamsPresenceBLE
  State: Running
  Author: DOMAIN\username
  Description: Monitors Microsoft Teams status...

Last Run Information:
  Last Run Time: 1/20/2025 8:30:00 AM
  Last Result: Currently Running (267009)
  Next Run Time: Not scheduled (triggered at logon)

Python Process:
  ✓ Running (PID: 12345)
    CPU: 2.34s
    Memory: 45.67 MB
    Started: 1/20/2025 8:30:15 AM

Bluetooth Status:
  ✓ Bluetooth adapter detected
    Intel(R) Wireless Bluetooth(R)
```

**PowerShell 5.1 Features**:
- Uses WMI for process command line detection (compatible with PSv5.1)
- Get-PnpDevice for Bluetooth status
- Clear status indicators

---

### Uninstall-TeamsBLEService.ps1

**Purpose**: Remove Teams BLE scheduled task

**Usage**:
```powershell
.\Uninstall-TeamsBLEService.ps1
```

**Features**:
- ✅ Stops running task
- ✅ Removes scheduled task
- ✅ Optionally removes wrapper script
- ✅ Confirmation prompts
- ✅ Preserves Python dependencies

**Safety**:
- Requires confirmation before removal
- Optional wrapper script deletion
- Does not uninstall Python packages

---

## PowerShell-based Servers (Alternative Methods)

### TeamsStatusServer.ps1

**Purpose**: HTTP server for WiFi devices (PyPortal, ESP32, etc.)

**Usage**:
```powershell
.\TeamsStatusServer.ps1 [-Port 8080] [-CheckInterval 5] [-Debug]
```

**Features**:
- HTTP endpoints on port 8080 (configurable)
- Returns JSON: `{"availability":"Available","activity":"Available","color":"#00FF00"}`
- Works with New Teams and Classic Teams

### TeamsStatusSerial.ps1

**Purpose**: USB serial server for direct-connected microcontrollers

**Usage**:
```powershell
.\TeamsStatusSerial.ps1 -ComPort COM3 [-BaudRate 115200] [-CheckInterval 5]
```

**Features**:
- Sends JSON over serial port
- 115200 baud (configurable)
- Works with any USB-serial microcontroller

---

## Comparison Matrix

| Method | Script | Connection | Best For | Power | Admin |
|--------|--------|------------|----------|-------|-------|
| **BLE** | Start-TeamsBLE.ps1 | Bluetooth | Work PCs, corporate networks | Battery | No |
| **HTTP** | TeamsStatusServer.ps1 | WiFi/LAN | Home networks, PyPortal | USB | Maybe* |
| **Serial** | TeamsStatusSerial.ps1 | USB Cable | When BT/WiFi unavailable | USB | No |

*Admin may be needed for firewall rules

---

## Management Commands

### Start Service
```powershell
# Manual mode
.\Start-TeamsBLE.ps1

# Scheduled task
Start-ScheduledTask -TaskName "MSTeamsPresenceBLE"
```

### Stop Service
```powershell
# Manual mode: Press Ctrl+C

# Scheduled task
Stop-ScheduledTask -TaskName "MSTeamsPresenceBLE"
```

### Restart Service
```powershell
Stop-ScheduledTask -TaskName "MSTeamsPresenceBLE"
Start-ScheduledTask -TaskName "MSTeamsPresenceBLE"
```

### Check Status
```powershell
.\Get-TeamsBLEServiceStatus.ps1

# Or
Get-ScheduledTask -TaskName "MSTeamsPresenceBLE"
```

### View Logs
```powershell
# Task Scheduler logs
eventvwr.msc
# Navigate to: Applications and Services → Microsoft → Windows → TaskScheduler
```

---

## PowerShell 5.1 Compatibility

All scripts are tested with PowerShell 5.1 (built into Windows 10/11):

**Compatible Features**:
- ✅ Scheduled Task cmdlets
- ✅ WMI process queries (for command line detection)
- ✅ Get-PnpDevice (Bluetooth status)
- ✅ Standard PowerShell 5.1 cmdlets

**Not Required**:
- ❌ PowerShell 7+ features
- ❌ External modules
- ❌ Admin rights (for BLE service)

---

## Troubleshooting

### Python Not Found
```powershell
# Specify Python path explicitly
.\Start-TeamsBLE.ps1 -PythonPath "C:\Python39\python.exe"

# Or add Python to PATH
$env:PATH += ";C:\Python39"
```

### Dependencies Failed to Install
```powershell
# Manual installation
pip install bleak psutil

# Or with specific Python version
python -m pip install bleak psutil
```

### RFduino Not Found
1. Ensure RFduino is powered on
2. Check Bluetooth is enabled: `Get-PnpDevice -Class Bluetooth`
3. Restart Bluetooth adapter
4. Move RFduino closer to PC

### Service Won't Start
```powershell
# Check task status
.\Get-TeamsBLEServiceStatus.ps1

# Check Event Viewer for errors
eventvwr.msc

# Try manual mode first
.\Start-TeamsBLE.ps1
```

### Process Detection Issues (PowerShell 5.1)
The status script uses WMI for process command line detection:
```powershell
# Verify WMI access
Get-WmiObject Win32_Process -Filter "Name LIKE 'python%.exe'"
```

---

## Next Steps

1. **Test manually**: `.\Start-TeamsBLE.ps1`
2. **Verify RFduino connection**: Check console output
3. **Test Teams status changes**: Change availability in Teams
4. **Optional**: Install as service with `.\Install-TeamsBLEService.ps1`

---

## Support

- **Script Issues**: Check console error messages
- **Python Issues**: Verify Python installation: `python --version`
- **RFduino Issues**: See [rfduino_firmware/README.md](../rfduino_firmware/README.md)
- **Teams Logs**: Ensure Teams is running and has logged events
