# Uninstall-TeamsBLEService.ps1
# Removes the Teams BLE Transmitter scheduled task

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Teams BLE Service Uninstaller" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$TaskName = "MSTeamsPresenceBLE"

# Check if task exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $existingTask) {
    Write-Host "[OK] Scheduled task not found: $TaskName" -ForegroundColor Yellow
    Write-Host "  Nothing to uninstall." -ForegroundColor Gray
    exit 0
}

Write-Host "Found scheduled task: $TaskName" -ForegroundColor Yellow
Write-Host "  State: $($existingTask.State)"
Write-Host "  Author: $($existingTask.Author)"
Write-Host ""

# Confirm removal
Write-Host "Are you sure you want to remove this task? (Y/N): " -ForegroundColor Yellow -NoNewline
$confirm = Read-Host

if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
    exit 0
}

# Stop task if running
Write-Host "`nStopping task if running..." -ForegroundColor Yellow
try {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Write-Host "[OK] Task stopped" -ForegroundColor Green
} catch {
    Write-Host "  Task was not running" -ForegroundColor Gray
}

# Remove task
Write-Host "Removing scheduled task..." -ForegroundColor Yellow
try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "[OK] Scheduled task removed: $TaskName" -ForegroundColor Green
} catch {
    Write-Host "[X] Failed to remove task: $_" -ForegroundColor Red
    exit 1
}

# Check for wrapper script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WrapperScript = Join-Path $ScriptDir "Run-TeamsBLE.ps1"

if (Test-Path $WrapperScript) {
    Write-Host "`nFound wrapper script: $WrapperScript" -ForegroundColor Yellow
    Write-Host "Remove wrapper script? (Y/N): " -ForegroundColor Yellow -NoNewline
    $removeWrapper = Read-Host

    if ($removeWrapper -eq "Y" -or $removeWrapper -eq "y") {
        try {
            Remove-Item $WrapperScript -Force
            Write-Host "[OK] Wrapper script removed" -ForegroundColor Green
        } catch {
            Write-Host "[X] Failed to remove wrapper: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Uninstallation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nThe Teams BLE service has been removed." -ForegroundColor Gray
Write-Host "Python dependencies (bleak, psutil) are still installed." -ForegroundColor Gray
Write-Host ""
