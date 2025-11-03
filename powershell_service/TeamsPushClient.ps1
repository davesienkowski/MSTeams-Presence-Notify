# MS Teams Status Push Client
# Monitors Teams logs and pushes status updates to Raspberry Pi at home
# Architecture: Work PC (client) → Raspberry Pi (server)

param(
    [string]$RaspberryPiIP = "192.168.50.137",  # Change to your Raspberry Pi's IP
    [int]$Port = 8080,
    [int]$PollInterval = 5  # Seconds between status checks
)

# Teams log file locations
# New Teams (Microsoft Teams 2.0)
$NewTeamsLogPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs\"
# Classic Teams
$ClassicTeamsLogPath = "$env:APPDATA\Microsoft\Teams\logs.txt"

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
    # Try New Teams first (returns directory path)
    if (Test-Path $NewTeamsLogPath) {
        return @{
            Path = $NewTeamsLogPath
            IsNewTeams = $true
        }
    }
    # Fall back to Classic Teams (returns file path)
    elseif (Test-Path $ClassicTeamsLogPath) {
        return @{
            Path = $ClassicTeamsLogPath
            IsNewTeams = $false
        }
    }
    else {
        return $null
    }
}

function Get-TeamsStatus {
    $logInfo = Get-TeamsLogPath

    if (-not $logInfo) {
        Write-Log "Teams log file not found. Is Teams running?" -Level "WARN"
        return @{
            Availability = "Unknown"
            Activity = "Unknown"
        }
    }

    try {
        $availability = "Unknown"
        $activity = "Unknown"
        $logContent = @()  # Initialize as array, not string

        if ($logInfo.IsNewTeams) {
            # New Teams: Read from the SINGLE most recent MSTeams_*.log file only
            $logFiles = Get-ChildItem -Path $logInfo.Path -Filter "MSTeams_*.log" -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -notmatch "Update|SlimCore|Launcher" } |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 1  # Only read the newest file

            if ($logFiles) {
                $newestFile = $logFiles[0]
                Write-Verbose "Reading from log file: $($newestFile.Name) (Modified: $($newestFile.LastWriteTime))" -Verbose
                # Read more lines to get more recent status entries
                $logContent = Get-Content $newestFile.FullName -Tail 5000 -ErrorAction SilentlyContinue
                Write-Verbose "Total lines read: $($logContent.Count)" -Verbose
            } else {
                Write-Verbose "No MSTeams log files found!" -Verbose
            }
        }
        else {
            # Classic Teams: Read from logs.txt
            $logContent = Get-Content $logInfo.Path -Tail 5000 -ErrorAction Stop
        }

        if ($logContent.Count -gt 0) {
            # Look for New Teams or Classic Teams status patterns
            $statusLines = $logContent | Where-Object {
                $_ -match "UserDataCrossCloudModule|UserPresenceAction|SetBadge.*status|StatusIndicatorStateService|NewActivity"
            }

            if ($statusLines) {
                # Get most recent status - take LAST 50 (most recent entries from the tail)
                # Ensure it's an array even if there's only one line
                $recentStatus = @($statusLines | Select-Object -Last 50)

                Write-Verbose "Found $($recentStatus.Count) status-related lines" -Verbose

                # Show the LAST few lines for debugging (most recent)
                if ($recentStatus.Count -gt 0) {
                    Write-Verbose "Sample of most recent status lines:" -Verbose
                    $samplesToShow = [Math]::Min(3, $recentStatus.Count)
                    # Show from end of array (most recent)
                    for ($j = 0; $j -lt $samplesToShow; $j++) {
                        $sampleLine = $recentStatus[$recentStatus.Count - 1 - $j]
                        # Extract timestamp from line
                        if ($sampleLine -match "^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})") {
                            $timestamp = $Matches[1]
                        } else {
                            $timestamp = "No timestamp"
                        }
                        $linePreview = if ($sampleLine.Length -gt 150) { $sampleLine.Substring(0, 150) } else { $sampleLine }
                        Write-Verbose "  [$timestamp] $linePreview" -Verbose
                    }
                }

                # Process in reverse order to get the most recent status first
                for ($i = $recentStatus.Count - 1; $i -ge 0; $i--) {
                    $line = $recentStatus[$i]

                    # New Teams patterns: UserDataCrossCloudModule or UserPresenceAction
                    # Must have "availability:" followed by a status keyword
                    if ($line -match "availability:\s*(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)[\s,}]") {
                        if ($availability -eq "Unknown") {
                            $availability = $Matches[1]
                            $activity = $Matches[1]
                            Write-Verbose "Matched availability pattern: $($Matches[1])" -Verbose
                            Write-Verbose "From line: $($line.Substring(0, [Math]::Min(150, $line.Length)))" -Verbose
                        }
                    }
                    # New Teams patterns: SetBadge status
                    # Must have "status " followed by a status keyword (with word boundary)
                    elseif ($line -match "status\s+(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)[\s,]") {
                        if ($availability -eq "Unknown") {
                            $availability = $Matches[1]
                            $activity = $Matches[1]
                            Write-Verbose "Matched status pattern: $($Matches[1])" -Verbose
                            Write-Verbose "From line: $($line.Substring(0, [Math]::Min(150, $line.Length)))" -Verbose
                        }
                    }
                    # Classic Teams patterns (fallback for older Teams)
                    elseif ($line -match "Setting the taskbar overlay icon - Available|NewActivity: Available") {
                        if ($availability -eq "Unknown") {
                            $availability = "Available"
                            $activity = "Available"
                            Write-Verbose "Matched Classic Teams Available pattern" -Verbose
                        }
                    }
                    elseif ($line -match "NewActivity: (InAMeeting|InACall|Busy)") {
                        if ($availability -eq "Unknown") {
                            $match = $Matches[1]
                            $availability = $match
                            $activity = $match
                            Write-Verbose "Matched Classic Teams activity pattern: $match" -Verbose
                        }
                    }
                    elseif ($line -match "NewActivity: Away|Setting the taskbar overlay icon - Away") {
                        if ($availability -eq "Unknown") {
                            $availability = "Away"
                            $activity = "Away"
                            Write-Verbose "Matched Classic Teams Away pattern" -Verbose
                        }
                    }
                    elseif ($line -match "NewActivity: BeRightBack") {
                        if ($availability -eq "Unknown") {
                            $availability = "BeRightBack"
                            $activity = "BeRightBack"
                            Write-Verbose "Matched Classic Teams BeRightBack pattern" -Verbose
                        }
                    }
                    elseif ($line -match "NewActivity: (DoNotDisturb|Presenting)") {
                        if ($availability -eq "Unknown") {
                            $availability = "DoNotDisturb"
                            $activity = "DoNotDisturb"
                            Write-Verbose "Matched Classic Teams DND pattern" -Verbose
                        }
                    }
                    elseif ($line -match "NewActivity: Offline") {
                        if ($availability -eq "Unknown") {
                            $availability = "Offline"
                            $activity = "Offline"
                            Write-Verbose "Matched Classic Teams Offline pattern" -Verbose
                        }
                    }

                    # Stop once we've found a status
                    if ($availability -ne "Unknown") {
                        break
                    }
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
        Write-Verbose "Retrieved status: $($status.Availability)" -Verbose

        # Check if status changed
        if ($status.Availability -ne $script:LastStatus -or $status.Activity -ne $script:LastActivity) {
            Write-Log "Status changed: $($script:LastStatus) → $($status.Availability)" -Level "SUCCESS"

            # Send update to Raspberry Pi
            if (Send-StatusUpdate -Availability $status.Availability -Activity $status.Activity) {
                Write-Log "Update sent successfully" -Level "SUCCESS"
                $script:LastStatus = $status.Availability
                $script:LastActivity = $status.Activity
                $consecutiveErrors = 0
            }
            else {
                $consecutiveErrors++
            }
        }
        else {
            Write-Verbose "Status unchanged: $($status.Availability)" -Verbose
        }

        # Check for too many consecutive errors
        if ($consecutiveErrors -ge $maxConsecutiveErrors) {
            Write-Log "Too many consecutive errors. Check Raspberry Pi connection." -Level "ERROR"
            $consecutiveErrors = 0  # Reset to avoid spam
        }

        # Wait before next check
        Write-Verbose "Waiting $PollInterval seconds before next check..." -Verbose
        Start-Sleep -Seconds $PollInterval
        Write-Verbose "Loop iteration complete, starting next check..." -Verbose
    }
    catch {
        Write-Log "Unexpected error: $_" -Level "ERROR"
        Write-Log "Error details: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
        Start-Sleep -Seconds $PollInterval
    }
}
