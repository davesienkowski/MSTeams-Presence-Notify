# MS Teams Status Push Client
# Monitors Teams logs and pushes status updates to Raspberry Pi at home
# Architecture: Work PC (client) → Raspberry Pi (server)

param(
    [string]$RaspberryPiIP = "192.168.50.137",  # Change to your Raspberry Pi's IP
    [int]$Port = 8080,
    [int]$PollInterval = 5,  # Seconds between status checks
    [switch]$Verbose  # Enable verbose debug output
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

$StatusEmoji = @{
    "Available" = "[OK]"
    "Busy" = "[!!]"
    "Away" = "[--]"
    "BeRightBack" = "[..]"
    "DoNotDisturb" = "[XX]"
    "InAMeeting" = "[!!]"
    "InACall" = "[!!]"
    "Offline" = "[  ]"
    "Unknown" = "[??]"
}

$StatusDisplayColor = @{
    "Available" = "Green"
    "Busy" = "Red"
    "Away" = "Yellow"
    "BeRightBack" = "Yellow"
    "DoNotDisturb" = "Magenta"
    "InAMeeting" = "Red"
    "InACall" = "Red"
    "Offline" = "DarkGray"
    "Unknown" = "White"
}

$script:LastStatus = $null
$script:LastActivity = $null
$script:VerboseMode = $Verbose
$script:ConnectionStatus = "Unknown"
$script:LastSuccessfulSend = $null

function Write-Debug-Log {
    param([string]$Message)
    if ($script:VerboseMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor DarkGray
    }
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        "WARN" { "Yellow" }
        "STATUS" { "Cyan" }
        default { "Gray" }
    }

    Write-Host "  $timestamp  " -NoNewline -ForegroundColor DarkGray
    Write-Host $Message -ForegroundColor $color
}

function Write-StatusChange {
    param([string]$OldStatus, [string]$NewStatus)

    $timestamp = Get-Date -Format "HH:mm:ss"
    $emoji = $StatusEmoji[$NewStatus]
    $color = $StatusDisplayColor[$NewStatus]

    Write-Host ""
    Write-Host "  $timestamp  " -NoNewline -ForegroundColor DarkGray
    Write-Host "$emoji " -NoNewline -ForegroundColor $color
    Write-Host "Teams Status: " -NoNewline -ForegroundColor Gray
    Write-Host $NewStatus -ForegroundColor $color
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
                Write-Debug-Log "Reading from log file: $($newestFile.Name)"
                $logContent = Get-Content $newestFile.FullName -Tail 5000 -ErrorAction SilentlyContinue
                Write-Debug-Log "Total lines read: $($logContent.Count)"
            } else {
                Write-Debug-Log "No MSTeams log files found!"
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
                $recentStatus = @($statusLines | Select-Object -Last 50)
                Write-Debug-Log "Found $($recentStatus.Count) status-related lines"

                # Process in reverse order to get the most recent status first
                for ($i = $recentStatus.Count - 1; $i -ge 0; $i--) {
                    $line = $recentStatus[$i]

                    # New Teams patterns: UserDataCrossCloudModule or UserPresenceAction
                    # Must have "availability:" followed by a status keyword
                    if ($line -match "availability:\s*(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)[\s,}]") {
                        if ($availability -eq "Unknown") {
                            $availability = $Matches[1]
                            $activity = $Matches[1]
                            Write-Debug-Log "Matched availability: $($Matches[1])"
                                                    }
                    }
                    # New Teams patterns: SetBadge status
                    # Must have "status " followed by a status keyword (with word boundary)
                    elseif ($line -match "status\s+(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)[\s,]") {
                        if ($availability -eq "Unknown") {
                            $availability = $Matches[1]
                            $activity = $Matches[1]
                            Write-Debug-Log "Matched status: $($Matches[1])"
                                                    }
                    }
                    # Classic Teams patterns (fallback for older Teams)
                    elseif ($line -match "Setting the taskbar overlay icon - Available|NewActivity: Available") {
                        if ($availability -eq "Unknown") {
                            $availability = "Available"
                            $activity = "Available"
                            Write-Debug-Log "Matched: Available (Classic)"
                        }
                    }
                    elseif ($line -match "NewActivity: (InAMeeting|InACall|Busy)") {
                        if ($availability -eq "Unknown") {
                            $match = $Matches[1]
                            $availability = $match
                            $activity = $match
                            Write-Debug-Log "Matched: $match (Classic)"
                        }
                    }
                    elseif ($line -match "NewActivity: Away|Setting the taskbar overlay icon - Away") {
                        if ($availability -eq "Unknown") {
                            $availability = "Away"
                            $activity = "Away"
                            Write-Debug-Log "Matched: Away (Classic)"
                        }
                    }
                    elseif ($line -match "NewActivity: BeRightBack") {
                        if ($availability -eq "Unknown") {
                            $availability = "BeRightBack"
                            $activity = "BeRightBack"
                            Write-Debug-Log "Matched: BeRightBack (Classic)"
                        }
                    }
                    elseif ($line -match "NewActivity: (DoNotDisturb|Presenting)") {
                        if ($availability -eq "Unknown") {
                            $availability = "DoNotDisturb"
                            $activity = "DoNotDisturb"
                            Write-Debug-Log "Matched: DoNotDisturb (Classic)"
                        }
                    }
                    elseif ($line -match "NewActivity: Offline") {
                        if ($availability -eq "Unknown") {
                            $availability = "Offline"
                            $activity = "Offline"
                            Write-Debug-Log "Matched: Offline (Classic)"
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
    param([switch]$Silent)

    $url = "http://${RaspberryPiIP}:${Port}/"

    try {
        $response = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 3
        if (-not $Silent) {
            Write-Log "Connected to Raspberry Pi" -Level "SUCCESS"
        }
        return $true
    }
    catch {
        if (-not $Silent) {
            Write-Log "Cannot reach Raspberry Pi at $RaspberryPiIP" -Level "ERROR"
        }
        return $false
    }
}

# Main execution
Clear-Host
Write-Host ""
Write-Host "  +====================================================================+" -ForegroundColor Cyan
Write-Host "  |              MS Teams Status Push Client                          |" -ForegroundColor Cyan
Write-Host "  +====================================================================+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  Configuration                                                     |" -ForegroundColor DarkGray
Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  Raspberry Pi:  " -NoNewline -ForegroundColor DarkGray
Write-Host "$RaspberryPiIP".PadRight(20) -NoNewline -ForegroundColor White
Write-Host "Port: " -NoNewline -ForegroundColor DarkGray
Write-Host "$Port".PadRight(10) -NoNewline -ForegroundColor White
Write-Host "          |" -ForegroundColor DarkGray
Write-Host "  |  Poll Interval: " -NoNewline -ForegroundColor DarkGray
Write-Host "${PollInterval}s".PadRight(51) -NoNewline -ForegroundColor White
Write-Host "|" -ForegroundColor DarkGray
Write-Host "  |  Connection:    " -NoNewline -ForegroundColor DarkGray

# Test connection to Raspberry Pi
$connectionOk = Test-RaspberryPiConnection -Silent
if ($connectionOk) {
    $script:ConnectionStatus = "Connected"
    $script:LastSuccessfulSend = Get-Date
    Write-Host "Connected".PadRight(51) -NoNewline -ForegroundColor Green
} else {
    $script:ConnectionStatus = "Disconnected"
    Write-Host "Disconnected".PadRight(51) -NoNewline -ForegroundColor Red
}
Write-Host "|" -ForegroundColor DarkGray
Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  Raspberry Pi Services                                             |" -ForegroundColor DarkGray
Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "  |  Web Dashboard:   " -NoNewline -ForegroundColor DarkGray
Write-Host "http://${RaspberryPiIP}:5000".PadRight(49) -NoNewline -ForegroundColor Cyan
Write-Host "|" -ForegroundColor DarkGray
Write-Host "  |  Status API:      " -NoNewline -ForegroundColor DarkGray
Write-Host "http://${RaspberryPiIP}:${Port}/status".PadRight(49) -NoNewline -ForegroundColor Cyan
Write-Host "|" -ForegroundColor DarkGray
Write-Host "  |  Home Assistant:  " -NoNewline -ForegroundColor DarkGray
Write-Host "Configure MQTT in config_push.yaml on Pi".PadRight(49) -NoNewline -ForegroundColor DarkGray
Write-Host "|" -ForegroundColor DarkGray
Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray

if (-not $connectionOk) {
    Write-Host ""
    Write-Host "  Connection failed. Ensure:" -ForegroundColor Yellow
    Write-Host "    - Raspberry Pi is on and running the server" -ForegroundColor Yellow
    Write-Host "    - IP address $RaspberryPiIP is correct" -ForegroundColor Yellow
    Write-Host "    - Port $Port is accessible" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Will retry on each status update..." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  --------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Monitoring Teams status... Press " -NoNewline -ForegroundColor Gray
Write-Host "Ctrl+C" -NoNewline -ForegroundColor Yellow
Write-Host " to stop" -ForegroundColor Gray
Write-Host "  --------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# Main monitoring loop
$consecutiveErrors = 0
$maxConsecutiveErrors = 5
$script:UpdateCount = 0

while ($true) {
    try {
        $status = Get-TeamsStatus
        Write-Debug-Log "Retrieved status: $($status.Availability)"

        # Check if status changed
        if ($status.Availability -ne $script:LastStatus -or $status.Activity -ne $script:LastActivity) {
            Write-StatusChange -OldStatus $script:LastStatus -NewStatus $status.Availability

            # Send update to Raspberry Pi
            if (Send-StatusUpdate -Availability $status.Availability -Activity $status.Activity) {
                $script:UpdateCount++
                $script:ConnectionStatus = "Connected"
                $script:LastSuccessfulSend = Get-Date
                Write-Host "             -> Raspberry Pi " -NoNewline -ForegroundColor DarkGray
                Write-Host "[Connected]" -ForegroundColor Green
                $script:LastStatus = $status.Availability
                $script:LastActivity = $status.Activity
                $consecutiveErrors = 0
            }
            else {
                $script:ConnectionStatus = "Disconnected"
                Write-Host "             -> Raspberry Pi " -NoNewline -ForegroundColor DarkGray
                Write-Host "[Disconnected]" -ForegroundColor Red
                $consecutiveErrors++
            }
        }
        else {
            Write-Debug-Log "Status unchanged: $($status.Availability)"
        }

        # Check for too many consecutive errors
        if ($consecutiveErrors -ge $maxConsecutiveErrors) {
            Write-Host ""
            Write-Host "  [!] Connection lost to $RaspberryPiIP - retrying..." -ForegroundColor Yellow
            $consecutiveErrors = 0
        }

        Write-Debug-Log "Waiting $PollInterval seconds..."
        Start-Sleep -Seconds $PollInterval
    }
    catch {
        Write-Host ""
        Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Write-Debug-Log "Stack trace: $($_.ScriptStackTrace)"
        Start-Sleep -Seconds $PollInterval
    }
}
