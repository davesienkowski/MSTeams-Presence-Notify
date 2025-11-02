# Install-TeamsBLEService.ps1
# Creates a Windows Scheduled Task to run Teams BLE Transmitter on login

param(
    [string]$PythonPath = "python",
    [int]$CheckInterval = 5,
    [string]$TeamsLogPath = "$env:APPDATA\Microsoft\Teams\logs.txt"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Teams BLE Service Installer" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get absolute paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$PythonScript = Join-Path $ProjectRoot "computer_service\teams_ble_transmitter.py"
$RequirementsFile = Join-Path $ProjectRoot "computer_service\requirements.txt"

# Validate files exist
Write-Host "Validating installation files..." -ForegroundColor Yellow

if (-not (Test-Path $PythonScript)) {
    Write-Host "[X] Python script not found: $PythonScript" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Found Python script: $PythonScript" -ForegroundColor Green

if (-not (Test-Path $RequirementsFile)) {
    Write-Host "[X] Requirements file not found: $RequirementsFile" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Found requirements file: $RequirementsFile" -ForegroundColor Green

# Test Python installation
Write-Host "`nTesting Python installation..." -ForegroundColor Yellow
try {
    $pythonVersion = & $PythonPath --version 2>&1
    Write-Host "[OK] Python found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "[X] Python not found or not in PATH" -ForegroundColor Red
    Write-Host "  Please install Python 3.8+ or specify path with -PythonPath" -ForegroundColor Yellow
    exit 1
}

# Check if dependencies are installed
Write-Host "`nChecking Python dependencies..." -ForegroundColor Yellow
$packagesInstalled = $true

$requiredPackages = @("bleak", "psutil")
foreach ($package in $requiredPackages) {
    $installed = & $PythonPath -m pip show $package 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [X] Missing: $package" -ForegroundColor Red
        $packagesInstalled = $false
    } else {
        Write-Host "  [OK] Installed: $package" -ForegroundColor Green
    }
}

# Install dependencies if needed
if (-not $packagesInstalled) {
    Write-Host "`nInstalling Python dependencies..." -ForegroundColor Yellow
    try {
        & $PythonPath -m pip install -r $RequirementsFile
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Dependencies installed successfully" -ForegroundColor Green
        } else {
            Write-Host "[X] Failed to install dependencies" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "[X] Error installing dependencies: $_" -ForegroundColor Red
        exit 1
    }
}

# Create wrapper script that runs Python with correct arguments
Write-Host "`nCreating service wrapper script..." -ForegroundColor Yellow
$WrapperScript = Join-Path $ScriptDir "Run-TeamsBLE.ps1"

$wrapperContent = @"
# Auto-generated wrapper script - DO NOT EDIT
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

`$PythonPath = "$PythonPath"
`$ScriptPath = "$PythonScript"
`$CheckInterval = $CheckInterval
`$TeamsLogPath = "$TeamsLogPath"

# Build arguments
`$arguments = @()
if (`$CheckInterval -ne 5) {
    `$arguments += "--interval", `$CheckInterval
}
if (`$TeamsLogPath) {
    `$arguments += "--log-path", `$TeamsLogPath
}

# Run Python script
Write-Host "Starting Teams BLE Transmitter..." -ForegroundColor Cyan
Write-Host "Python: `$PythonPath" -ForegroundColor Gray
Write-Host "Script: `$ScriptPath" -ForegroundColor Gray
Write-Host "Interval: `$CheckInterval seconds" -ForegroundColor Gray
Write-Host "Log Path: `$TeamsLogPath" -ForegroundColor Gray
Write-Host ""

try {
    & `$PythonPath `$ScriptPath @arguments
} catch {
    Write-Host "Error running Teams BLE Transmitter: `$_" -ForegroundColor Red
    Start-Sleep -Seconds 10
    exit 1
}
"@

Set-Content -Path $WrapperScript -Value $wrapperContent -Force
Write-Host "[OK] Created wrapper: $WrapperScript" -ForegroundColor Green

# Create scheduled task
Write-Host "`nCreating scheduled task..." -ForegroundColor Yellow

$TaskName = "MSTeamsPresenceBLE"
$TaskDescription = "Monitors Microsoft Teams status and broadcasts via Bluetooth LE to RFduino"

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "[!] Scheduled task already exists: $TaskName" -ForegroundColor Yellow
    $response = Read-Host "Do you want to replace it? (Y/N)"
    if ($response -ne "Y" -and $response -ne "y") {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "[OK] Removed existing task" -ForegroundColor Green
}

# Create task action
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$WrapperScript`"" `
    -WorkingDirectory $ScriptDir

# Create task trigger (at logon)
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

# Create task settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0)  # No time limit

# Create task principal (run as current user)
$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

# Register the task
try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Description $TaskDescription `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Force | Out-Null

    Write-Host "[OK] Scheduled task created: $TaskName" -ForegroundColor Green
} catch {
    Write-Host "[X] Failed to create scheduled task: $_" -ForegroundColor Red
    exit 1
}

# Show task details
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nTask Details:" -ForegroundColor Yellow
Write-Host "  Name: $TaskName"
Write-Host "  Trigger: At user logon ($env:USERNAME)"
Write-Host "  Action: Run Teams BLE Transmitter"
Write-Host "  Auto-restart: 3 attempts (1 minute interval)"
Write-Host "  Working Directory: $ScriptDir"

Write-Host "`nManagement Commands:" -ForegroundColor Yellow
Write-Host "  Start now:    " -NoNewline
Write-Host "Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Cyan
Write-Host "  Stop:         " -NoNewline
Write-Host "Stop-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Cyan
Write-Host "  View status:  " -NoNewline
Write-Host "Get-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Cyan
Write-Host "  Uninstall:    " -NoNewline
Write-Host ".\Uninstall-TeamsBLEService.ps1" -ForegroundColor Cyan

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Ensure your RFduino is powered on and nearby"
Write-Host "  2. Restart your computer (task runs at login)"
Write-Host "  3. Or start manually with: Start-ScheduledTask -TaskName '$TaskName'"

Write-Host "`nWould you like to start the service now? (Y/N): " -ForegroundColor Yellow -NoNewline
$startNow = Read-Host
if ($startNow -eq "Y" -or $startNow -eq "y") {
    Write-Host "`nStarting service..." -ForegroundColor Yellow
    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 2

    $taskInfo = Get-ScheduledTask -TaskName $TaskName
    Write-Host "[OK] Service started - State: $($taskInfo.State)" -ForegroundColor Green
    Write-Host "`nCheck Task Scheduler or Event Viewer for logs" -ForegroundColor Gray
}

Write-Host ""
