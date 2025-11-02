# Test script for Teams Status Server
# Verifies Teams installation, log files, and HTTP server
# PowerShell 5.1+ Compatible

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Teams Status Server - Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$AllTestsPassed = $true

# Test 1: Check Teams installation
Write-Host "[1/6] Checking Teams installation..." -ForegroundColor Yellow
$TeamsProcess = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue

if ($TeamsProcess)
{
    Write-Host "  [OK] Teams is running" -ForegroundColor Green
    Write-Host "    Process ID: $($TeamsProcess.Id)" -ForegroundColor Gray
}
else
{
    Write-Host "  [FAIL] Teams is NOT running" -ForegroundColor Red
    Write-Host "    Please start Microsoft Teams and try again" -ForegroundColor Yellow
    $AllTestsPassed = $false
}

# Test 2: Check New Teams log directory
Write-Host ""
Write-Host "[2/6] Checking New Teams log directory..." -ForegroundColor Yellow
$NewTeamsLogPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs\"

if (Test-Path -Path $NewTeamsLogPath)
{
    Write-Host "  [OK] New Teams log directory found" -ForegroundColor Green
    Write-Host "    Path: $NewTeamsLogPath" -ForegroundColor Gray

    $LogFiles = Get-ChildItem -Path $NewTeamsLogPath -Filter "*.log" -ErrorAction SilentlyContinue
    if ($LogFiles)
    {
        Write-Host "    Log files: $($LogFiles.Count)" -ForegroundColor Gray
        $LatestLog = $LogFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $LogSizeKB = [math]::Round($LatestLog.Length / 1KB, 2)
        Write-Host "    Latest: $($LatestLog.Name) ($LogSizeKB KB)" -ForegroundColor Gray
    }
    else
    {
        Write-Host "  [WARNING] No log files found (Teams may need to be restarted)" -ForegroundColor Yellow
    }
}
else
{
    Write-Host "  [FAIL] New Teams log directory NOT found" -ForegroundColor Red

    # Check Classic Teams as fallback
    $ClassicTeamsLogPath = "$env:APPDATA\Microsoft\Teams\logs.txt"
    if (Test-Path -Path $ClassicTeamsLogPath)
    {
        Write-Host "  [OK] Classic Teams log file found (fallback)" -ForegroundColor Yellow
        Write-Host "    Path: $ClassicTeamsLogPath" -ForegroundColor Gray
        Write-Host "    Note: Classic Teams support ends July 1, 2025" -ForegroundColor Yellow
    }
    else
    {
        Write-Host "  [FAIL] No Teams logs found at all" -ForegroundColor Red
        $AllTestsPassed = $false
    }
}

# Test 3: Check log content
Write-Host ""
Write-Host "[3/6] Checking log content..." -ForegroundColor Yellow

try
{
    if (Test-Path -Path $NewTeamsLogPath)
    {
        $LogFiles = Get-ChildItem -Path $NewTeamsLogPath -Filter "*.log" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

        if ($LogFiles)
        {
            $LogContent = Get-Content -Path $LogFiles[0].FullName -Tail 500 -ErrorAction SilentlyContinue | Out-String

            if ($LogContent -match "SetBadge|SetTaskbarIconOverlay")
            {
                Write-Host "  [OK] Status patterns found in logs" -ForegroundColor Green

                # Try to detect current status
                if ($LogContent -match "SetBadge Setting badge:.*available")
                {
                    Write-Host "    Detected: Available" -ForegroundColor Gray
                }
                elseif ($LogContent -match "SetBadge Setting badge:.*busy")
                {
                    Write-Host "    Detected: Busy" -ForegroundColor Gray
                }
                elseif ($LogContent -match "SetBadge Setting badge:.*away")
                {
                    Write-Host "    Detected: Away" -ForegroundColor Gray
                }
                elseif ($LogContent -match "SetBadge Setting badge:.*doNotDisturb")
                {
                    Write-Host "    Detected: Do Not Disturb" -ForegroundColor Gray
                }
                else
                {
                    Write-Host "    Detected: (checking...)" -ForegroundColor Gray
                }
            }
            else
            {
                Write-Host "  [WARNING] Status patterns NOT found in recent logs" -ForegroundColor Yellow
                Write-Host "    Try changing your Teams status to generate log entries" -ForegroundColor Yellow
            }
        }
    }
}
catch
{
    Write-Host "  [WARNING] Could not read log content: $_" -ForegroundColor Yellow
}

# Test 4: Check if port 8080 is available
Write-Host ""
Write-Host "[4/6] Checking port 8080 availability..." -ForegroundColor Yellow

$PortInUse = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue

if ($PortInUse)
{
    Write-Host "  [WARNING] Port 8080 is already in use" -ForegroundColor Yellow
    Write-Host "    Process ID: $($PortInUse.OwningProcess)" -ForegroundColor Gray

    $Process = Get-Process -Id $PortInUse.OwningProcess -ErrorAction SilentlyContinue
    if ($Process)
    {
        Write-Host "    Process Name: $($Process.ProcessName)" -ForegroundColor Gray
        if ($Process.ProcessName -like "*powershell*")
        {
            Write-Host "    This might be our Teams Status Server already running!" -ForegroundColor Cyan
        }
    }
}
else
{
    Write-Host "  [OK] Port 8080 is available" -ForegroundColor Green
}

# Test 5: Check network configuration
Write-Host ""
Write-Host "[5/6] Checking network configuration..." -ForegroundColor Yellow

$IPv4Addresses = Get-NetIPAddress -AddressFamily IPv4 |
                 Where-Object {$_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*"} |
                 Select-Object -ExpandProperty IPAddress

if ($IPv4Addresses)
{
    Write-Host "  [OK] Network adapters found" -ForegroundColor Green
    foreach ($IP in $IPv4Addresses)
    {
        Write-Host "    $IP" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "  PyPortal should connect to: http://$($IPv4Addresses[0]):8080/status" -ForegroundColor Cyan
}
else
{
    Write-Host "  [WARNING] No non-loopback IPv4 addresses found" -ForegroundColor Yellow
}

# Test 6: Try to start server (if not running)
Write-Host ""
Write-Host "[6/6] Testing server startup..." -ForegroundColor Yellow

if (-not $PortInUse)
{
    Write-Host "  Attempting to start server for 5 seconds..." -ForegroundColor Gray

    # Start server in background job
    $TestJob = Start-Job -ScriptBlock {
        param($ScriptPath)
        & $ScriptPath -CheckInterval 2
    } -ArgumentList "$PSScriptRoot\TeamsStatusServer.ps1"

    Start-Sleep -Seconds 3

    # Test HTTP endpoint
    try
    {
        $Response = Invoke-WebRequest -Uri "http://localhost:8080/status" -TimeoutSec 2 -ErrorAction Stop
        $Status = $Response.Content | ConvertFrom-Json

        Write-Host "  [OK] Server started successfully!" -ForegroundColor Green
        Write-Host "    Status: $($Status.availability)" -ForegroundColor Gray
        Write-Host "    Color: $($Status.color)" -ForegroundColor Gray
    }
    catch
    {
        Write-Host "  [WARNING] Could not connect to server: $_" -ForegroundColor Yellow
    }

    # Stop test server
    Stop-Job $TestJob -ErrorAction SilentlyContinue
    Remove-Job $TestJob -ErrorAction SilentlyContinue
}
else
{
    Write-Host "  Skipped (port already in use - server may already be running)" -ForegroundColor Yellow
    Write-Host "  Try testing manually: Invoke-WebRequest http://localhost:8080/status" -ForegroundColor Cyan
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($AllTestsPassed -and $TeamsProcess)
{
    Write-Host "[OK] All critical tests passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You're ready to run the Teams Status Server:" -ForegroundColor White
    Write-Host "  powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1" -ForegroundColor Cyan
    Write-Host ""
}
else
{
    Write-Host "[WARNING] Some tests failed or require attention" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please address the issues above before running the server." -ForegroundColor White
    Write-Host ""
}

# Next steps
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Start the server: powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1" -ForegroundColor White
Write-Host "  2. Test endpoint: Invoke-WebRequest http://localhost:8080/status" -ForegroundColor White
Write-Host "  3. Get your IP: ipconfig" -ForegroundColor White
Write-Host "  4. Configure PyPortal with: http://<your-ip>:8080/status" -ForegroundColor White
Write-Host ""
