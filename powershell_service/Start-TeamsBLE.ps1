# Start-TeamsBLE.ps1
# Simple launcher for Teams BLE Transmitter (Manual Operation)

param(
    [string]$PythonPath = "python",
    [int]$CheckInterval = 5,
    [string]$TeamsLogPath = "$env:APPDATA\Microsoft\Teams\logs.txt"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Teams BLE Transmitter Launcher" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$PythonScript = Join-Path $ProjectRoot "computer_service\teams_ble_transmitter.py"
$RequirementsFile = Join-Path $ProjectRoot "computer_service\requirements.txt"

# Validate Python script exists
if (-not (Test-Path $PythonScript)) {
    Write-Host "[X] Python script not found: $PythonScript" -ForegroundColor Red
    exit 1
}

# Test Python
Write-Host "Checking Python installation..." -ForegroundColor Yellow
try {
    $pythonVersion = & $PythonPath --version 2>&1
    Write-Host "[OK] Python: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "[X] Python not found. Please install Python 3.8+ or specify -PythonPath" -ForegroundColor Red
    exit 1
}

# Check dependencies
Write-Host "Checking dependencies..." -ForegroundColor Yellow
$requiredPackages = @("bleak", "psutil")
$missingPackages = @()

foreach ($package in $requiredPackages) {
    $installed = & $PythonPath -m pip show $package 2>&1
    if ($LASTEXITCODE -ne 0) {
        $missingPackages += $package
    }
}

if ($missingPackages.Count -gt 0) {
    Write-Host "[X] Missing packages: $($missingPackages -join ', ')" -ForegroundColor Red
    Write-Host "`nInstalling dependencies..." -ForegroundColor Yellow

    try {
        & $PythonPath -m pip install -r $RequirementsFile
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Dependencies installed" -ForegroundColor Green
        } else {
            Write-Host "[X] Failed to install dependencies" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "[X] Error: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[OK] All dependencies installed" -ForegroundColor Green
}

# Build arguments
$arguments = @()
if ($CheckInterval -ne 5) {
    $arguments += "--interval", $CheckInterval
}
if ($TeamsLogPath) {
    $arguments += "--log-path", $TeamsLogPath
}

# Display configuration
Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  Python: $PythonPath"
Write-Host "  Script: $PythonScript"
Write-Host "  Check Interval: $CheckInterval seconds"
Write-Host "  Teams Log: $TeamsLogPath"
Write-Host ""

# Start the service
Write-Host "Starting Teams BLE Transmitter..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Gray

try {
    & $PythonPath $PythonScript @arguments
} catch {
    Write-Host "`n[X] Error: $_" -ForegroundColor Red
    exit 1
}
