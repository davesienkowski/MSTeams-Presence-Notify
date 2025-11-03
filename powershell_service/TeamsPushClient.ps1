# MS Teams Status Push Client
# Monitors Teams logs and pushes status updates to Raspberry Pi at home
# Architecture: Work PC (client) → Raspberry Pi (server)

param(
    [string]$RaspberryPiIP = "192.168.1.150",  # Change to your Raspberry Pi's IP
    [int]$Port = 8080,
    [int]$PollInterval = 5  # Seconds between status checks
)

# Teams log file locations
$TeamsLogsPath = "$env:APPDATA\Microsoft\Teams\logs.txt"
$OldTeamsLogsPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Teams\logs.txt"

# Status mapping
$StatusColors = @{
    "Available" = "#00FF00"
    "Busy" = "#FF0000"
    "Away" = "#FFFF00"
    "BeRightBack" = "#FFFF00"
    "DoNotDisturb" = "#800080"
    "InAMeeting" = "#FF0000"
    "InACall" = "#FF0000"
    "Offline" = "#808080"
    "Unknown" = "#FFFFFF"
}

$script:LastStatus = $null
$script:LastActivity = $null

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        "WARN" { "Yellow" }
        default { "White" }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-TeamsLogPath {
    # Try new Teams first, then old Teams
    if (Test-Path $TeamsLogsPath) {
        return $TeamsLogsPath
    }
    elseif (Test-Path $OldTeamsLogsPath) {
        return $OldTeamsLogsPath
    }
    else {
        return $null
    }
}

function Get-TeamsStatus {
    $logPath = Get-TeamsLogPath

    if (-not $logPath) {
        Write-Log "Teams log file not found. Is Teams running?" -Level "WARN"
        return @{
            Availability = "Unknown"
            Activity = "Unknown"
        }
    }

    try {
        # Read last 5000 lines for better status detection
        $logContent = Get-Content $logPath -Tail 5000 -ErrorAction Stop

        # Parse status from log patterns
        $availability = "Unknown"
        $activity = "Unknown"

        # Look for StatusIndicatorStateService messages
        $statusLines = $logContent | Where-Object { $_ -match "StatusIndicatorStateService|SetBadge|NotifyCall" }

        if ($statusLines) {
            # Get most recent status
            $recentStatus = $statusLines | Select-Object -Last 10

            foreach ($line in $recentStatus) {
                # Available
                if ($line -match "Setting the taskbar overlay icon - Available|NewActivity: Available") {
                    $availability = "Available"
                    $activity = "Available"
                }
                # Busy / In a Meeting / In a Call
                elseif ($line -match "NewActivity: (InAMeeting|InACall|Busy)") {
                    $match = $Matches[1]
                    $availability = $match
                    $activity = $match
                }
                # Away
                elseif ($line -match "NewActivity: Away|Setting the taskbar overlay icon - Away") {
                    $availability = "Away"
                    $activity = "Away"
                }
                # Be Right Back
                elseif ($line -match "NewActivity: BeRightBack") {
                    $availability = "BeRightBack"
                    $activity = "BeRightBack"
                }
                # Do Not Disturb
                elseif ($line -match "NewActivity: (DoNotDisturb|Presenting)") {
                    $availability = "DoNotDisturb"
                    $activity = "DoNotDisturb"
                }
                # Offline
                elseif ($line -match "NewActivity: Offline") {
                    $availability = "Offline"
                    $activity = "Offline"
                }
            }
        }

        return @{
            Availability = $availability
            Activity = $activity
        }
    }
    catch {
        Write-Log "Error reading Teams log: $_" -Level "ERROR"
        return @{
            Availability = "Unknown"
            Activity = "Unknown"
        }
    }
}

function Send-StatusUpdate {
    param(
        [string]$Availability,
        [string]$Activity
    )

    $url = "http://${RaspberryPiIP}:${Port}/status"

    $payload = @{
        availability = $Availability
        activity = $Activity
        color = $StatusColors[$Availability]
        timestamp = (Get-Date).ToString("o")
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $url -Method POST -Body $payload -ContentType "application/json" -TimeoutSec 3
        return $true
    }
    catch {
        Write-Log "Failed to send update to Raspberry Pi: $_" -Level "ERROR"
        return $false
    }
}

function Test-RaspberryPiConnection {
    $url = "http://${RaspberryPiIP}:${Port}/"

    try {
        $response = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 3
        Write-Log "Successfully connected to Raspberry Pi at $RaspberryPiIP" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Cannot reach Raspberry Pi at $RaspberryPiIP. Is the server running?" -Level "ERROR"
        return $false
    }
}

# Main execution
Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host " MS Teams Status Push Client" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""
Write-Log "Raspberry Pi IP: $RaspberryPiIP"
Write-Log "Port: $Port"
Write-Log "Poll interval: $PollInterval seconds"
Write-Host ""

# Test connection to Raspberry Pi
Write-Log "Testing connection to Raspberry Pi..."
if (-not (Test-RaspberryPiConnection)) {
    Write-Host ""
    Write-Log "Please ensure:" -Level "WARN"
    Write-Log "  1. Raspberry Pi is powered on and running teams_status_server.py" -Level "WARN"
    Write-Log "  2. IP address is correct: $RaspberryPiIP" -Level "WARN"
    Write-Log "  3. Port $Port is accessible from this PC" -Level "WARN"
    Write-Host ""
    Write-Log "Continuing anyway... Will retry on each update." -Level "WARN"
}

Write-Host ""
Write-Log "Starting Teams status monitoring..."
Write-Log "Press Ctrl+C to stop"
Write-Host ""

# Main monitoring loop
$consecutiveErrors = 0
$maxConsecutiveErrors = 5

while ($true) {
    try {
        # Get current Teams status
        $status = Get-TeamsStatus

        # Check if status changed
        if ($status.Availability -ne $script:LastStatus -or $status.Activity -ne $script:LastActivity) {
            Write-Log "Status changed: $($script:LastStatus) → $($status.Availability)" -Level "SUCCESS"

            # Send update to Raspberry Pi
            if (Send-StatusUpdate -Availability $status.Availability -Activity $status.Activity) {
                $script:LastStatus = $status.Availability
                $script:LastActivity = $status.Activity
                $consecutiveErrors = 0
            }
            else {
                $consecutiveErrors++
            }
        }

        # Check for too many consecutive errors
        if ($consecutiveErrors -ge $maxConsecutiveErrors) {
            Write-Log "Too many consecutive errors. Check Raspberry Pi connection." -Level "ERROR"
            $consecutiveErrors = 0  # Reset to avoid spam
        }

        # Wait before next check
        Start-Sleep -Seconds $PollInterval
    }
    catch {
        Write-Log "Unexpected error: $_" -Level "ERROR"
        Start-Sleep -Seconds $PollInterval
    }
}
