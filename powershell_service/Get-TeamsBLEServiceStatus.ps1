# Get-TeamsBLEServiceStatus.ps1
# Shows status of the Teams BLE Transmitter service

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Teams BLE Service Status" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$TaskName = "MSTeamsPresenceBLE"

# Check if task exists
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $task) {
    Write-Host "[X] Service not installed" -ForegroundColor Red
    Write-Host "`nTo install, run: .\Install-TeamsBLEService.ps1" -ForegroundColor Yellow
    exit 1
}

# Display task information
Write-Host "Service Status:" -ForegroundColor Yellow
Write-Host "  Task Name: " -NoNewline
Write-Host $task.TaskName -ForegroundColor Cyan

Write-Host "  State: " -NoNewline
switch ($task.State) {
    "Ready"    { Write-Host "Ready (not running)" -ForegroundColor Green }
    "Running"  { Write-Host "Running" -ForegroundColor Green }
    "Disabled" { Write-Host "Disabled" -ForegroundColor Yellow }
    default    { Write-Host $task.State -ForegroundColor Yellow }
}

Write-Host "  Author: " -NoNewline
Write-Host $task.Author -ForegroundColor Gray

Write-Host "  Description: " -NoNewline
Write-Host $task.Description -ForegroundColor Gray

# Get last run information
$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
if ($taskInfo) {
    Write-Host "`nLast Run Information:" -ForegroundColor Yellow
    Write-Host "  Last Run Time: " -NoNewline
    if ($taskInfo.LastRunTime -eq (Get-Date "1/1/1999")) {
        Write-Host "Never" -ForegroundColor Gray
    } else {
        Write-Host $taskInfo.LastRunTime -ForegroundColor Gray
    }

    Write-Host "  Last Result: " -NoNewline
    if ($taskInfo.LastTaskResult -eq 0) {
        Write-Host "Success (0)" -ForegroundColor Green
    } elseif ($taskInfo.LastTaskResult -eq 267009) {
        Write-Host "Currently Running (267009)" -ForegroundColor Cyan
    } elseif ($taskInfo.LastTaskResult -eq 1) {
        Write-Host "Failed (1)" -ForegroundColor Red
    } else {
        Write-Host "$($taskInfo.LastTaskResult)" -ForegroundColor Yellow
    }

    Write-Host "  Next Run Time: " -NoNewline
    if ($taskInfo.NextRunTime) {
        Write-Host $taskInfo.NextRunTime -ForegroundColor Gray
    } else {
        Write-Host "Not scheduled (triggered at logon)" -ForegroundColor Gray
    }

    Write-Host "  Number of Missed Runs: " -NoNewline
    Write-Host $taskInfo.NumberOfMissedRuns -ForegroundColor Gray
}

# Check for running Python process
Write-Host "`nPython Process:" -ForegroundColor Yellow

# PowerShell 5.1 compatible process check using WMI
$pythonProcesses = Get-WmiObject Win32_Process -Filter "Name LIKE 'python%.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*teams_ble_transmitter*" }

if ($pythonProcesses) {
    foreach ($proc in $pythonProcesses) {
        # Get process details from Get-Process for additional info
        $procDetails = Get-Process -Id $proc.ProcessId -ErrorAction SilentlyContinue

        Write-Host "  [OK] Running (PID: $($proc.ProcessId))" -ForegroundColor Green
        if ($procDetails) {
            Write-Host "    CPU: $([math]::Round($procDetails.CPU, 2))s" -ForegroundColor Gray
            Write-Host "    Memory: $([math]::Round($procDetails.WorkingSet / 1MB, 2)) MB" -ForegroundColor Gray
            Write-Host "    Started: $($procDetails.StartTime)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  [X] Not running" -ForegroundColor Yellow
}

# Check BLE connectivity
Write-Host "`nBluetooth Status:" -ForegroundColor Yellow
try {
    $bluetooth = Get-PnpDevice -Class Bluetooth -Status OK -ErrorAction SilentlyContinue
    if ($bluetooth) {
        Write-Host "  [OK] Bluetooth adapter detected" -ForegroundColor Green
        $bluetooth | ForEach-Object {
            Write-Host "    $($_.FriendlyName)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [!] No Bluetooth adapter found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [?] Unable to check Bluetooth status" -ForegroundColor Gray
}

# Management commands
Write-Host "`nManagement Commands:" -ForegroundColor Yellow
Write-Host "  Start:        " -NoNewline
Write-Host "Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Cyan
Write-Host "  Stop:         " -NoNewline
Write-Host "Stop-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Cyan
Write-Host "  Restart:      " -NoNewline
Write-Host "Stop-ScheduledTask -TaskName '$TaskName'; Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Cyan
Write-Host "  Uninstall:    " -NoNewline
Write-Host ".\Uninstall-TeamsBLEService.ps1" -ForegroundColor Cyan

# Check logs
Write-Host "`nLogs:" -ForegroundColor Yellow
Write-Host "  Task Scheduler: eventvwr.msc → Applications and Services → Microsoft → Windows → TaskScheduler" -ForegroundColor Gray

Write-Host ""
