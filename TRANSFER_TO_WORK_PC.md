# Transfer Instructions for Work PC

## Project Locations

- **Dev PC (Current)**: `D:\Repos\MSTeams-Presence-Notify`
- **Work PC (Target)**: `C:\Repositories\MSTeams-Presence-Notify`

## Quick Transfer Instructions

### Method 1: Compress and Copy (Recommended)

**On Dev PC:**
```powershell
# Navigate to parent directory
D:
cd D:\Repos

# Create zip file
Compress-Archive -Path "MSTeams-Presence-Notify" -DestinationPath "MSTeams-Presence-Notify.zip" -Force

# Copy to USB drive, network share, or OneDrive
Copy-Item "MSTeams-Presence-Notify.zip" -Destination "E:\" # Change E: to your USB drive
```

**On Work PC:**
```powershell
# Copy from USB to work PC
Copy-Item "E:\MSTeams-Presence-Notify.zip" -Destination "C:\Repositories\" # Change E: to your USB drive

# Navigate to target location
cd C:\Repositories

# Extract the zip
Expand-Archive -Path "MSTeams-Presence-Notify.zip" -DestinationPath "." -Force

# Navigate into folder
cd MSTeams-Presence-Notify

# Verify project
powershell -ExecutionPolicy Bypass -File Verify-Project.ps1
```

### Method 2: Direct Copy (If Network Share Available)

```powershell
# If you have a network share accessible from both PCs
robocopy "D:\Repos\MSTeams-Presence-Notify" "\\NetworkShare\MSTeams-Presence-Notify" /E /Z

# Then from Work PC
robocopy "\\NetworkShare\MSTeams-Presence-Notify" "C:\Repositories\MSTeams-Presence-Notify" /E /Z
```

### Method 3: Git (If Available)

**On Dev PC:**
```powershell
cd D:\Repos\MSTeams-Presence-Notify

# Initialize git if not already
git init
git add .
git commit -m "Initial commit"

# Push to your remote (GitHub, Azure DevOps, etc.)
git remote add origin <your-repo-url>
git push -u origin main
```

**On Work PC:**
```powershell
cd C:\Repositories
git clone <your-repo-url> MSTeams-Presence-Notify
```

## After Transfer - Verify on Work PC

### 1. Run Verification Script

```powershell
cd C:\Repositories\MSTeams-Presence-Notify
powershell -ExecutionPolicy Bypass -File Verify-Project.ps1
```

**Expected Output:**
```
========================================
MS Teams Presence PyPortal - Project Verification
========================================

Project Location: C:\Repositories\MSTeams-Presence-Notify

[1/5] Checking Documentation...
  [OK] Main README
  [OK] Complete project plan
  [OK] PowerShell quick start guide
  [OK] Alternative methods documentation

[2/5] Checking PowerShell Service...
  [OK] Main server script
  [OK] Diagnostics script
  [OK] PowerShell service documentation

...

[OK] All critical files are present!

Project Status: READY
```

### 2. Run Diagnostics

**IMPORTANT: Make sure Microsoft Teams is running first!**

```powershell
cd powershell_service
powershell -ExecutionPolicy Bypass -File Test-TeamsStatus.ps1
```

### 3. Start the Server

If diagnostics pass:

```powershell
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1
```

### 4. Test the Endpoint

Open a NEW PowerShell window:

```powershell
Invoke-WebRequest -Uri http://localhost:8080/status | ConvertFrom-Json
```

## Files You Need to Transfer

**Essential Files (MUST have):**
```
MSTeams-Presence-Notify/
├── powershell_service/
│   ├── TeamsStatusServer.ps1      (Main server)
│   ├── Test-TeamsStatus.ps1       (Diagnostics)
│   └── README.md                  (Documentation)
│
├── Verify-Project.ps1             (Verification script)
└── README.md                      (Project overview)
```

**Optional but Helpful:**
```
├── docs/
│   ├── QUICK_START_POWERSHELL.md
│   └── ALTERNATIVE_METHODS.md
│
└── TRANSFER_TO_WORK_PC.md         (This file)
```

**Not Needed (for PowerShell method):**
```
├── computer_service/              (Only for Graph API method)
├── requirements.txt               (Only for Graph API method)
└── env.example                    (Only for Graph API method)
```

## PowerShell 5.1 Compatibility

Your work PC is using PowerShell 5.1, which is fully supported. All scripts have been updated to be PowerShell 5.1 compatible with:
- Explicit parameter names
- No Unicode special characters in status output
- Proper bracket formatting
- Compatible cmdlet syntax

## Troubleshooting

### Issue: Execution Policy Error

```powershell
# Run PowerShell as Administrator and execute:
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force
```

### Issue: Port 8080 In Use

```powershell
# Check what's using the port
netstat -ano | findstr :8080

# Kill the process if safe
taskkill /F /PID <process-id>
```

### Issue: Firewall Blocking

```powershell
# Run PowerShell as Administrator
netsh advfirewall firewall add rule name="Teams Presence Service" dir=in action=allow protocol=TCP localport=8080
```

## Quick Reference Commands

```powershell
# Verify project
cd C:\Repositories\MSTeams-Presence-Notify
powershell -ExecutionPolicy Bypass -File Verify-Project.ps1

# Run diagnostics
cd powershell_service
powershell -ExecutionPolicy Bypass -File Test-TeamsStatus.ps1

# Start server
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1

# Test endpoint (in NEW window)
Invoke-WebRequest -Uri http://localhost:8080/status | ConvertFrom-Json

# Get your work PC's IP (for PyPortal)
ipconfig | findstr IPv4
```

## What to Report Back

After testing on your work PC, report:

1. ✅ Did verification pass?
2. ✅ Did diagnostics pass?
3. ✅ What is your work PC's IP address?
4. ✅ Did the server start successfully?
5. ✅ Does status detection work when you change Teams status?
6. ✅ Any error messages encountered?

Once confirmed working, we'll proceed with PyPortal code and setup!
