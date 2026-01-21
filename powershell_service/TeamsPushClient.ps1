# MS Teams Status Push Client
# Monitors Teams logs and pushes status updates to Raspberry Pi at home
# Architecture: Work PC (client) -> Raspberry Pi (server)

param(
    [string]$RaspberryPiIP = "192.168.50.137",  # Change to your Raspberry Pi's IP
    [int]$Port = 8080,
    [int]$PollInterval = 5,  # Seconds between status checks
    [switch]$Verbose  # Enable verbose debug output
)

# ANSI escape sequence (works in Windows Terminal, PS7+, and most modern terminals)
$ESC = [char]27

# Teams log file locations
$NewTeamsLogPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs\"
$ClassicTeamsLogPath = "$env:APPDATA\Microsoft\Teams\logs.txt"

# Status mapping
$StatusColors = @{
    "Available" = "#00FF00"; "Busy" = "#FF0000"; "Away" = "#FFFF00"
    "BeRightBack" = "#FFFF00"; "DoNotDisturb" = "#800080"; "InAMeeting" = "#FF0000"
    "InACall" = "#FF0000"; "Offline" = "#808080"; "Unknown" = "#FFFFFF"
}

$StatusEmoji = @{
    "Available" = "[OK]"; "Busy" = "[!!]"; "Away" = "[--]"; "BeRightBack" = "[..]"
    "DoNotDisturb" = "[XX]"; "InAMeeting" = "[!!]"; "InACall" = "[!!]"
    "Offline" = "[  ]"; "Unknown" = "[??]"
}

$StatusDisplayColor = @{
    "Available" = "Green"; "Busy" = "Red"; "Away" = "Yellow"; "BeRightBack" = "Yellow"
    "DoNotDisturb" = "Magenta"; "InAMeeting" = "Red"; "InACall" = "Red"
    "Offline" = "DarkGray"; "Unknown" = "White"
}

# Script state
$script:LastStatus = $null
$script:LastActivity = $null
$script:VerboseMode = $Verbose
$script:LastSuccessfulSend = $null
$script:UpdateCount = 0
$script:StatusHistory = @()
$script:MaxHistory = 5
$script:LastPollTime = $null
$script:IsConnected = $false

# UI row tracking (0-based from top of drawn UI)
$script:UIStartRow = 0
$script:TotalUIRows = 0

function Get-TeamsLogPath {
    if (Test-Path $NewTeamsLogPath) {
        return @{ Path = $NewTeamsLogPath; IsNewTeams = $true }
    }
    elseif (Test-Path $ClassicTeamsLogPath) {
        return @{ Path = $ClassicTeamsLogPath; IsNewTeams = $false }
    }
    return $null
}

function Get-TeamsStatus {
    $logInfo = Get-TeamsLogPath
    if (-not $logInfo) {
        return @{ Availability = "Unknown"; Activity = "Unknown" }
    }

    try {
        $logContent = @()
        if ($logInfo.IsNewTeams) {
            $logFiles = Get-ChildItem -Path $logInfo.Path -Filter "MSTeams_*.log" -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -notmatch "Update|SlimCore|Launcher" } |
                        Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($logFiles) {
                $logContent = Get-Content $logFiles[0].FullName -Tail 5000 -ErrorAction SilentlyContinue
            }
        }
        else {
            $logContent = Get-Content $logInfo.Path -Tail 5000 -ErrorAction Stop
        }

        if ($logContent.Count -gt 0) {
            $statusLines = $logContent | Where-Object {
                $_ -match "UserDataCrossCloudModule|UserPresenceAction|SetBadge.*status|StatusIndicatorStateService|NewActivity"
            }
            if ($statusLines) {
                $recentStatus = @($statusLines | Select-Object -Last 50)
                for ($i = $recentStatus.Count - 1; $i -ge 0; $i--) {
                    $line = $recentStatus[$i]
                    if ($line -match "availability:\s*(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)[\s,}]") {
                        return @{ Availability = $Matches[1]; Activity = $Matches[1] }
                    }
                    elseif ($line -match "status\s+(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)[\s,]") {
                        return @{ Availability = $Matches[1]; Activity = $Matches[1] }
                    }
                    elseif ($line -match "Setting the taskbar overlay icon - (Available|Away)|NewActivity: (Available|Away)") {
                        $status = if ($Matches[1]) { $Matches[1] } else { $Matches[2] }
                        return @{ Availability = $status; Activity = $status }
                    }
                    elseif ($line -match "NewActivity: (InAMeeting|InACall|Busy)") {
                        return @{ Availability = $Matches[1]; Activity = $Matches[1] }
                    }
                    elseif ($line -match "NewActivity: BeRightBack") {
                        return @{ Availability = "BeRightBack"; Activity = "BeRightBack" }
                    }
                    elseif ($line -match "NewActivity: (DoNotDisturb|Presenting)") {
                        return @{ Availability = "DoNotDisturb"; Activity = "DoNotDisturb" }
                    }
                    elseif ($line -match "NewActivity: Offline") {
                        return @{ Availability = "Offline"; Activity = "Offline" }
                    }
                }
            }
        }
        return @{ Availability = "Unknown"; Activity = "Unknown" }
    }
    catch {
        return @{ Availability = "Unknown"; Activity = "Unknown" }
    }
}

function Send-StatusUpdate {
    param([string]$Availability, [string]$Activity)
    $url = "http://${RaspberryPiIP}:${Port}/status"
    $payload = @{
        availability = $Availability
        activity = $Activity
        color = $StatusColors[$Availability]
        timestamp = (Get-Date).ToString("o")
    } | ConvertTo-Json

    try {
        $null = Invoke-RestMethod -Uri $url -Method POST -Body $payload -ContentType "application/json" -TimeoutSec 3
        return $true
    }
    catch { return $false }
}

function Test-RaspberryPiConnection {
    try {
        $null = Invoke-RestMethod -Uri "http://${RaspberryPiIP}:${Port}/" -Method GET -TimeoutSec 3
        return $true
    }
    catch { return $false }
}

function Move-ToRow {
    param([int]$Row)
    $absoluteRow = $script:UIStartRow + $Row
    [Console]::SetCursorPosition(0, $absoluteRow)
}

function Write-Line {
    param([string]$Text, [string]$Color = "White", [switch]$NoClear)
    if (-not $NoClear) {
        Write-Host "`r$(' ' * 74)" -NoNewline
        Write-Host "`r" -NoNewline
    }
    Write-Host $Text -ForegroundColor $Color -NoNewline
}

function Draw-UI {
    param(
        [string]$CurrentStatus = "Unknown",
        [string]$LastUpdateTime = "--:--:--",
        [string]$LastPollTime = "--:--:--",
        [int]$Countdown = $PollInterval,
        [bool]$Connected = $false,
        [int]$UpdatesSent = 0
    )

    $emoji = $StatusEmoji[$CurrentStatus]
    $statusColor = $StatusDisplayColor[$CurrentStatus]
    $connColor = if ($Connected) { "Green" } else { "Red" }
    $connText = if ($Connected) { "Connected" } else { "Disconnected" }

    Clear-Host
    $script:UIStartRow = [Console]::CursorTop

    # Header
    Write-Host ""
    Write-Host "  ======================================================================" -ForegroundColor Cyan
    Write-Host "                    MS Teams Status Push Client" -ForegroundColor Cyan
    Write-Host "  ======================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Config section
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   Configuration" -ForegroundColor White
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   Raspberry Pi:  " -NoNewline -ForegroundColor DarkGray
    Write-Host $RaspberryPiIP -NoNewline -ForegroundColor White
    Write-Host "     Port: " -NoNewline -ForegroundColor DarkGray
    Write-Host $Port -ForegroundColor White
    Write-Host "   Poll Interval: " -NoNewline -ForegroundColor DarkGray
    Write-Host "${PollInterval}s" -ForegroundColor White
    Write-Host ""

    # Services section
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   Raspberry Pi Services" -ForegroundColor White
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   Web Dashboard:   " -NoNewline -ForegroundColor DarkGray
    Write-Host "http://${RaspberryPiIP}:5000" -ForegroundColor Cyan
    Write-Host "   Status API:      " -NoNewline -ForegroundColor DarkGray
    Write-Host "http://${RaspberryPiIP}:${Port}/status" -ForegroundColor Cyan
    Write-Host "   Home Assistant:  " -NoNewline -ForegroundColor DarkGray
    Write-Host "MQTT (configure on Pi)" -ForegroundColor DarkGray
    Write-Host "   Notifications:   " -NoNewline -ForegroundColor DarkGray
    Write-Host "ntfy.sh (configure on Pi)" -ForegroundColor DarkGray
    Write-Host ""

    # Current Status section
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   Current Status" -ForegroundColor White
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    $script:StatusLineRow = [Console]::CursorTop
    Write-Host "   " -NoNewline
    Write-Host "$emoji " -NoNewline -ForegroundColor $statusColor
    Write-Host $CurrentStatus.PadRight(15) -NoNewline -ForegroundColor $statusColor
    Write-Host "Last update: $LastUpdateTime" -ForegroundColor DarkGray
    Write-Host ""

    # History section
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   Recent Changes" -ForegroundColor White
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    $script:HistoryStartRow = [Console]::CursorTop
    for ($i = 0; $i -lt $script:MaxHistory; $i++) {
        if ($i -lt $script:StatusHistory.Count) {
            $entry = $script:StatusHistory[$script:StatusHistory.Count - 1 - $i]
            $hEmoji = $StatusEmoji[$entry.Status]
            $hColor = $StatusDisplayColor[$entry.Status]
            $hTime = $entry.Time.ToString("HH:mm:ss")
            $sentText = if ($entry.Sent) { "[Sent]" } else { "[Failed]" }
            $sentColor = if ($entry.Sent) { "Green" } else { "Red" }

            Write-Host "   $hTime  " -NoNewline -ForegroundColor DarkGray
            Write-Host "$hEmoji " -NoNewline -ForegroundColor $hColor
            Write-Host $entry.Status.PadRight(14) -NoNewline -ForegroundColor $hColor
            Write-Host "-> Pi " -NoNewline -ForegroundColor DarkGray
            Write-Host $sentText -ForegroundColor $sentColor
        }
        else {
            Write-Host "   -" -ForegroundColor DarkGray
        }
    }
    Write-Host ""

    # Connection section
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    $script:ConnectionRow = [Console]::CursorTop
    Write-Host "   Connection: " -NoNewline -ForegroundColor DarkGray
    Write-Host $connText.PadRight(14) -NoNewline -ForegroundColor $connColor
    Write-Host "Updates sent: " -NoNewline -ForegroundColor DarkGray
    Write-Host $UpdatesSent -ForegroundColor White
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    # Footer with countdown
    $script:FooterRow = [Console]::CursorTop
    Write-Host "  Last poll: $LastPollTime  |  Next in: $($Countdown.ToString().PadLeft(2))s  |  Ctrl+C to stop" -ForegroundColor DarkGray

    $script:TotalUIRows = [Console]::CursorTop - $script:UIStartRow

    # Hide cursor
    [Console]::CursorVisible = $false
}

function Update-StatusLine {
    param([string]$Status, [string]$UpdateTime)

    $emoji = $StatusEmoji[$Status]
    $color = $StatusDisplayColor[$Status]

    [Console]::SetCursorPosition(0, $script:StatusLineRow)
    Write-Host "   " -NoNewline
    Write-Host "$emoji " -NoNewline -ForegroundColor $color
    Write-Host $Status.PadRight(15) -NoNewline -ForegroundColor $color
    Write-Host "Last update: $UpdateTime".PadRight(30) -ForegroundColor DarkGray
}

function Update-ConnectionLine {
    param([bool]$Connected, [int]$UpdatesSent)

    $connColor = if ($Connected) { "Green" } else { "Red" }
    $connText = if ($Connected) { "Connected" } else { "Disconnected" }

    [Console]::SetCursorPosition(0, $script:ConnectionRow)
    Write-Host "   Connection: " -NoNewline -ForegroundColor DarkGray
    Write-Host $connText.PadRight(14) -NoNewline -ForegroundColor $connColor
    Write-Host "Updates sent: " -NoNewline -ForegroundColor DarkGray
    Write-Host "$UpdatesSent".PadRight(10) -ForegroundColor White
}

function Update-Footer {
    param([string]$PollTime, [int]$Countdown)

    [Console]::SetCursorPosition(0, $script:FooterRow)
    Write-Host "  Last poll: $PollTime  |  Next in: $($Countdown.ToString().PadLeft(2))s  |  Ctrl+C to stop     " -ForegroundColor DarkGray
}

function Update-HistorySection {
    for ($i = 0; $i -lt $script:MaxHistory; $i++) {
        [Console]::SetCursorPosition(0, $script:HistoryStartRow + $i)

        if ($i -lt $script:StatusHistory.Count) {
            $entry = $script:StatusHistory[$script:StatusHistory.Count - 1 - $i]
            $hEmoji = $StatusEmoji[$entry.Status]
            $hColor = $StatusDisplayColor[$entry.Status]
            $hTime = $entry.Time.ToString("HH:mm:ss")
            $sentText = if ($entry.Sent) { "[Sent]" } else { "[Failed]" }
            $sentColor = if ($entry.Sent) { "Green" } else { "Red" }

            Write-Host "   $hTime  " -NoNewline -ForegroundColor DarkGray
            Write-Host "$hEmoji " -NoNewline -ForegroundColor $hColor
            Write-Host $entry.Status.PadRight(14) -NoNewline -ForegroundColor $hColor
            Write-Host "-> Pi " -NoNewline -ForegroundColor DarkGray
            Write-Host $sentText.PadRight(15) -ForegroundColor $sentColor
        }
        else {
            Write-Host "   -".PadRight(60) -ForegroundColor DarkGray
        }
    }
}

function Add-StatusToHistory {
    param([string]$Status, [bool]$Sent)

    $script:StatusHistory += @{
        Status = $Status
        Time = Get-Date
        Sent = $Sent
    }

    if ($script:StatusHistory.Count -gt $script:MaxHistory) {
        $script:StatusHistory = $script:StatusHistory | Select-Object -Last $script:MaxHistory
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Initial UI draw
Draw-UI -CurrentStatus "Unknown" -Connected $false -UpdatesSent 0

# Test initial connection
$script:IsConnected = Test-RaspberryPiConnection
Update-ConnectionLine -Connected $script:IsConnected -UpdatesSent $script:UpdateCount

# Main monitoring loop with countdown
$consecutiveErrors = 0
$maxConsecutiveErrors = 5
# Initialize to trigger immediate first poll
$lastCheckTime = (Get-Date).AddSeconds(-$PollInterval - 1)

try {
    while ($true) {
        $now = Get-Date
        $secondsSinceLastCheck = ($now - $lastCheckTime).TotalSeconds

        # Calculate countdown (cap secondsSinceLastCheck to avoid overflow)
        $cappedSeconds = [Math]::Min($secondsSinceLastCheck, $PollInterval + 1)
        $countdown = [Math]::Max(0, $PollInterval - [int]$cappedSeconds)

        # Update footer with countdown every iteration
        $pollTimeStr = if ($script:LastPollTime) { $script:LastPollTime.ToString("HH:mm:ss") } else { "--:--:--" }
        Update-Footer -PollTime $pollTimeStr -Countdown $countdown

        # Time to poll?
        if ($secondsSinceLastCheck -ge $PollInterval) {
            $script:LastPollTime = $now
            $lastCheckTime = $now

            try {
                $status = Get-TeamsStatus

                # Always update current status display
                $updateTimeStr = $now.ToString("HH:mm:ss")
                Update-StatusLine -Status $status.Availability -UpdateTime $updateTimeStr

                # Check if status changed
                if ($status.Availability -ne $script:LastStatus -or $status.Activity -ne $script:LastActivity) {

                    # Send update to Raspberry Pi
                    $sent = Send-StatusUpdate -Availability $status.Availability -Activity $status.Activity

                    if ($sent) {
                        $script:UpdateCount++
                        $script:IsConnected = $true
                        $script:LastSuccessfulSend = $now
                        $consecutiveErrors = 0
                    }
                    else {
                        $script:IsConnected = $false
                        $consecutiveErrors++
                    }

                    # Add to history and update display
                    Add-StatusToHistory -Status $status.Availability -Sent $sent
                    Update-HistorySection
                    Update-ConnectionLine -Connected $script:IsConnected -UpdatesSent $script:UpdateCount

                    $script:LastStatus = $status.Availability
                    $script:LastActivity = $status.Activity
                }

                # Check for too many consecutive errors
                if ($consecutiveErrors -ge $maxConsecutiveErrors) {
                    $script:IsConnected = Test-RaspberryPiConnection
                    Update-ConnectionLine -Connected $script:IsConnected -UpdatesSent $script:UpdateCount
                    $consecutiveErrors = 0
                }
            }
            catch {
                # Silently continue on errors
            }
        }

        # Short sleep for responsive countdown (update ~2x per second)
        Start-Sleep -Milliseconds 500
    }
}
finally {
    # Restore cursor and clean exit
    [Console]::CursorVisible = $true
    [Console]::SetCursorPosition(0, $script:FooterRow + 2)
    Write-Host ""
    Write-Host "  Stopped." -ForegroundColor Yellow
}
