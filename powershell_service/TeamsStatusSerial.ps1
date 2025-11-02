# Teams Status USB Serial Server for PyPortal
# Sends Teams presence status over USB serial connection
# No network required - perfect for restricted work environments

param(
    [string]$ComPort = "COM3",
    [int]$BaudRate = 115200,
    [int]$CheckInterval = 5,
    [switch]$Debug
)

# Configuration
$LocalUsername = $env:USERNAME
$TeamsLogPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs\"
$ClassicTeamsLogPath = "$env:APPDATA\Microsoft\Teams\logs.txt"

# Check which Teams version is installed
$UseNewTeams = Test-Path $TeamsLogPath
$UseClassicTeams = Test-Path $ClassicTeamsLogPath

if (-not $UseNewTeams -and -not $UseClassicTeams) {
    Write-Host "ERROR: Could not find Teams log directory!" -ForegroundColor Red
    Write-Host "New Teams path: $TeamsLogPath" -ForegroundColor Yellow
    Write-Host "Classic Teams path: $ClassicTeamsLogPath" -ForegroundColor Yellow
    exit 1
}

if ($UseNewTeams) {
    Write-Host "Detected: New Teams (recommended)" -ForegroundColor Green
    $LogPath = $TeamsLogPath
} else {
    Write-Host "Detected: Classic Teams (support ends July 2025)" -ForegroundColor Yellow
    $LogPath = $ClassicTeamsLogPath
}

# Status color mapping for PyPortal
$ColorMap = @{
    "Available" = "#00FF00"       # Green
    "Busy" = "#FF0000"            # Red
    "Away" = "#FFFF00"            # Yellow
    "BeRightBack" = "#FFFF00"     # Yellow
    "DoNotDisturb" = "#800080"    # Purple
    "Focusing" = "#800080"        # Purple
    "Presenting" = "#FF0000"      # Red
    "InAMeeting" = "#FF0000"      # Red
    "InACall" = "#FF0000"         # Red
    "Offline" = "#808080"         # Gray
    "Unknown" = "#FFFFFF"         # White
}

# Function to parse Teams logs
function Get-TeamsStatus {
    param($LogPath, $UseNewTeams)

    try {
        $TeamsProcess = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue

        if (-not $TeamsProcess) {
            return @{
                availability = "Offline"
                activity = "Offline"
                detected = $true
            }
        }

        if ($UseNewTeams) {
            $LogFiles = Get-ChildItem -Path $LogPath -Filter "*.log" -ErrorAction SilentlyContinue |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 3

            if (-not $LogFiles) {
                return @{ detected = $false }
            }

            $LogContent = ""
            foreach ($LogFile in $LogFiles) {
                $LogContent += Get-Content -Path $LogFile.FullName -Tail 500 -ErrorAction SilentlyContinue | Out-String
            }
        }
        else {
            $LogContent = Get-Content -Path $LogPath -Tail 1000 -ErrorAction SilentlyContinue | Out-String
        }

        if ([string]::IsNullOrWhiteSpace($LogContent)) {
            return @{ detected = $false }
        }

        $result = @{
            availability = "Unknown"
            activity = "Unknown"
            detected = $true
        }

        # Parse availability status
        if ($LogContent -match "SetBadge Setting badge:.*doNotDisturb|Do not disturb") {
            $result.availability = "DoNotDisturb"
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*focusing") {
            $result.availability = "Focusing"
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*presenting") {
            $result.availability = "Presenting"
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*inameeting|InAMeeting") {
            $result.availability = "InAMeeting"
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*busy") {
            $result.availability = "Busy"
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*away") {
            $result.availability = "Away"
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*berightback|BeRightBack") {
            $result.availability = "BeRightBack"
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*available") {
            $result.availability = "Available"
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*offline") {
            $result.availability = "Offline"
        }

        # Parse activity
        if ($LogContent -match "NotifyCallActive|NotifyCallAccepted") {
            $result.activity = "InACall"
        }
        elseif ($LogContent -match "NotifyCallEnded") {
            $result.activity = "Available"
        }
        else {
            $result.activity = $result.availability
        }

        return $result
    }
    catch {
        Write-Host "Error parsing Teams logs: $_" -ForegroundColor Red
        return @{ detected = $false }
    }
}

# List available COM ports
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Teams Status USB Serial Server" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Available COM Ports:" -ForegroundColor Yellow
[System.IO.Ports.SerialPort]::GetPortNames() | ForEach-Object {
    Write-Host "  $_" -ForegroundColor White
}

# Try to open serial port
Write-Host "`nOpening serial port: $ComPort @ $BaudRate baud" -ForegroundColor Yellow

try {
    $SerialPort = New-Object System.IO.Ports.SerialPort
    $SerialPort.PortName = $ComPort
    $SerialPort.BaudRate = $BaudRate
    $SerialPort.DataBits = 8
    $SerialPort.Parity = [System.IO.Ports.Parity]::None
    $SerialPort.StopBits = [System.IO.Ports.StopBits]::One
    $SerialPort.Handshake = [System.IO.Ports.Handshake]::None
    $SerialPort.ReadTimeout = 500
    $SerialPort.WriteTimeout = 500
    $SerialPort.DtrEnable = $true
    $SerialPort.RtsEnable = $true

    $SerialPort.Open()
    Write-Host "✓ Serial port opened successfully" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Could not open serial port $ComPort" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check if PyPortal is connected via USB" -ForegroundColor White
    Write-Host "2. Verify the correct COM port in Device Manager" -ForegroundColor White
    Write-Host "3. Close any other programs using the serial port (Arduino IDE, PuTTY, etc.)" -ForegroundColor White
    Write-Host "4. Try a different COM port: -ComPort COM4" -ForegroundColor White
    exit 1
}

Write-Host "`nConfiguration:" -ForegroundColor Yellow
Write-Host "  COM Port: $ComPort" -ForegroundColor White
Write-Host "  Baud Rate: $BaudRate" -ForegroundColor White
Write-Host "  Check Interval: $CheckInterval seconds" -ForegroundColor White
Write-Host "  Log Path: $LogPath" -ForegroundColor White
Write-Host "  Debug Mode: $Debug`n" -ForegroundColor White

Write-Host "Press Ctrl+C to stop the server`n" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

# Initial status check
Write-Host "Performing initial status check..." -ForegroundColor Cyan
$CurrentStatus = Get-TeamsStatus -LogPath $LogPath -UseNewTeams $UseNewTeams

if ($CurrentStatus.detected) {
    $availability = $CurrentStatus.availability
    $activity = $CurrentStatus.activity
    $color = $ColorMap[$availability]
    if (-not $color) { $color = "#FFFFFF" }

    Write-Host "Initial status: $availability`n" -ForegroundColor Green

    # Send initial status
    $json = @{
        availability = $availability
        activity = $activity
        color = $color
    } | ConvertTo-Json -Compress

    try {
        $SerialPort.WriteLine($json)
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Sent: $json" -ForegroundColor Green
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Error sending: $_" -ForegroundColor Red
    }
}
else {
    Write-Host "Could not detect Teams status" -ForegroundColor Yellow
}

# Main monitoring loop
$LastStatus = ""
$UpdateCount = 0

try {
    while ($true) {
        Start-Sleep -Seconds $CheckInterval

        $NewStatus = Get-TeamsStatus -LogPath $LogPath -UseNewTeams $UseNewTeams

        if ($NewStatus.detected) {
            $availability = $NewStatus.availability
            $activity = $NewStatus.activity
            $color = $ColorMap[$availability]
            if (-not $color) { $color = "#FFFFFF" }

            # Build JSON
            $json = @{
                availability = $availability
                activity = $activity
                color = $color
            } | ConvertTo-Json -Compress

            # Only send if status changed or every 10 updates (keep-alive)
            if ($json -ne $LastStatus -or ($UpdateCount % 10 -eq 0)) {
                try {
                    $SerialPort.WriteLine($json)
                    $UpdateCount++

                    if ($json -ne $LastStatus) {
                        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Status changed: $availability" -ForegroundColor Green
                    }
                    else {
                        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Keep-alive: $availability" -ForegroundColor Cyan
                    }

                    if ($Debug) {
                        Write-Host "  Sent: $json" -ForegroundColor Gray
                    }

                    $LastStatus = $json
                }
                catch {
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Error sending: $_" -ForegroundColor Red
                }
            }
        }
    }
}
catch {
    # Ctrl+C pressed
}
finally {
    Write-Host "`nShutting down..." -ForegroundColor Yellow
    if ($SerialPort -and $SerialPort.IsOpen) {
        $SerialPort.Close()
        $SerialPort.Dispose()
    }
    Write-Host "Serial port closed." -ForegroundColor Green
}
