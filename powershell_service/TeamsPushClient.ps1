# MS Teams Status Push Client
# Monitors Teams logs and pushes status updates to Raspberry Pi at home
# Architecture: Work PC (client) -> Raspberry Pi (server)

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

# Script state
$script:LastStatus = $null
$script:LastActivity = $null
$script:VerboseMode = $Verbose
$script:ConnectionStatus = "Unknown"
$script:LastSuccessfulSend = $null
$script:UpdateCount = 0
$script:StatusHistory = @()
$script:MaxHistory = 5

# UI Layout positions (row numbers)
$script:CurrentStatusRow = 0
$script:HistoryStartRow = 0
$script:ConnectionRow = 0
$script:LastPollRow = 0

function Write-Debug-Log {
    param([string]$Message)
    if ($script:VerboseMode) {
        # In verbose mode, write to a separate area at the bottom
        $savedPos = $Host.UI.RawUI.CursorPosition
        [Console]::SetCursorPosition(0, $script:LastPollRow + 2)
        Write-Host "[DEBUG] $Message".PadRight(70) -ForegroundColor DarkGray
        $Host.UI.RawUI.CursorPosition = $savedPos
    }
}

function Write-AtPosition {
    param(
        [int]$Row,
        [int]$Col,
        [string]$Text,
        [string]$Color = "White"
    )
    [Console]::SetCursorPosition($Col, $Row)
    Write-Host $Text -NoNewline -ForegroundColor $Color
}

function Clear-Line {
    param([int]$Row)
    [Console]::SetCursorPosition(0, $Row)
    Write-Host (" " * 72) -NoNewline
}

function Update-CurrentStatus {
    param([string]$Status)

    $emoji = $StatusEmoji[$Status]
    $color = $StatusDisplayColor[$Status]

    # Clear and update current status line
    Clear-Line -Row $script:CurrentStatusRow
    Write-AtPosition -Row $script:CurrentStatusRow -Col 2 -Text "|  " -Color DarkGray
    Write-AtPosition -Row $script:CurrentStatusRow -Col 5 -Text "$emoji " -Color $color
    Write-AtPosition -Row $script:CurrentStatusRow -Col 10 -Text $Status.PadRight(20) -Color $color

    # Show time since last change
    $timeStr = (Get-Date).ToString("HH:mm:ss")
    Write-AtPosition -Row $script:CurrentStatusRow -Col 32 -Text "Last update: $timeStr".PadRight(35) -Color DarkGray
    Write-AtPosition -Row $script:CurrentStatusRow -Col 69 -Text "|" -Color DarkGray
}

function Update-History {
    # Display last N status changes
    for ($i = 0; $i -lt $script:MaxHistory; $i++) {
        $row = $script:HistoryStartRow + $i
        Clear-Line -Row $row
        Write-AtPosition -Row $row -Col 2 -Text "|  " -Color DarkGray

        if ($i -lt $script:StatusHistory.Count) {
            $entry = $script:StatusHistory[$script:StatusHistory.Count - 1 - $i]
            $emoji = $StatusEmoji[$entry.Status]
            $color = $StatusDisplayColor[$entry.Status]
            $timeStr = $entry.Time.ToString("HH:mm:ss")

            Write-AtPosition -Row $row -Col 5 -Text $timeStr -Color DarkGray
            Write-AtPosition -Row $row -Col 15 -Text "$emoji " -Color $color
            Write-AtPosition -Row $row -Col 20 -Text $entry.Status.PadRight(15) -Color $color
            Write-AtPosition -Row $row -Col 36 -Text "-> Pi " -Color DarkGray

            if ($entry.Sent) {
                Write-AtPosition -Row $row -Col 42 -Text "[Sent]".PadRight(25) -Color Green
            } else {
                Write-AtPosition -Row $row -Col 42 -Text "[Failed]".PadRight(25) -Color Red
            }
        } else {
            Write-AtPosition -Row $row -Col 5 -Text "-".PadRight(62) -Color DarkGray
        }
        Write-AtPosition -Row $row -Col 69 -Text "|" -Color DarkGray
    }
}

function Update-ConnectionStatus {
    param([bool]$Connected)

    Clear-Line -Row $script:ConnectionRow
    Write-AtPosition -Row $script:ConnectionRow -Col 2 -Text "|  Connection: " -Color DarkGray

    if ($Connected) {
        Write-AtPosition -Row $script:ConnectionRow -Col 16 -Text "Connected".PadRight(15) -Color Green
    } else {
        Write-AtPosition -Row $script:ConnectionRow -Col 16 -Text "Disconnected".PadRight(15) -Color Red
    }

    Write-AtPosition -Row $script:ConnectionRow -Col 33 -Text "Updates sent: $($script:UpdateCount)".PadRight(34) -Color DarkGray
    Write-AtPosition -Row $script:ConnectionRow -Col 69 -Text "|" -Color DarkGray
}

function Update-LastPoll {
    $timeStr = (Get-Date).ToString("HH:mm:ss")
    Clear-Line -Row $script:LastPollRow
    Write-AtPosition -Row $script:LastPollRow -Col 2 -Text "  Last poll: $timeStr" -Color DarkGray
    Write-AtPosition -Row $script:LastPollRow -Col 30 -Text "| Next in: ${PollInterval}s" -Color DarkGray
    Write-AtPosition -Row $script:LastPollRow -Col 50 -Text "| Press Ctrl+C to stop" -Color DarkGray
}

function Add-StatusToHistory {
    param(
        [string]$Status,
        [bool]$Sent
    )

    $entry = @{
        Status = $Status
        Time = Get-Date
        Sent = $Sent
    }

    $script:StatusHistory += $entry

    # Keep only last N entries
    if ($script:StatusHistory.Count -gt $script:MaxHistory) {
        $script:StatusHistory = $script:StatusHistory | Select-Object -Last $script:MaxHistory
    }
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
        Write-Debug-Log "Teams log file not found. Is Teams running?"
        return @{
            Availability = "Unknown"
            Activity = "Unknown"
        }
    }

    try {
        $availability = "Unknown"
        $activity = "Unknown"
        $logContent = @()

        if ($logInfo.IsNewTeams) {
            $logFiles = Get-ChildItem -Path $logInfo.Path -Filter "MSTeams_*.log" -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -notmatch "Update|SlimCore|Launcher" } |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 1

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
            $logContent = Get-Content $logInfo.Path -Tail 5000 -ErrorAction Stop
        }

        if ($logContent.Count -gt 0) {
            $statusLines = $logContent | Where-Object {
                $_ -match "UserDataCrossCloudModule|UserPresenceAction|SetBadge.*status|StatusIndicatorStateService|NewActivity"
            }

            if ($statusLines) {
                $recentStatus = @($statusLines | Select-Object -Last 50)
                Write-Debug-Log "Found $($recentStatus.Count) status-related lines"

                for ($i = $recentStatus.Count - 1; $i -ge 0; $i--) {
                    $line = $recentStatus[$i]

                    if ($line -match "availability:\s*(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)[\s,}]") {
                        if ($availability -eq "Unknown") {
                            $availability = $Matches[1]
                            $activity = $Matches[1]
                            Write-Debug-Log "Matched availability: $($Matches[1])"
                        }
                    }
                    elseif ($line -match "status\s+(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)[\s,]") {
                        if ($availability -eq "Unknown") {
                            $availability = $Matches[1]
                            $activity = $Matches[1]
                            Write-Debug-Log "Matched status: $($Matches[1])"
                        }
                    }
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
        Write-Debug-Log "Error reading Teams log: $_"
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
        Write-Debug-Log "Failed to send update to Raspberry Pi: $_"
        return $false
    }
}

function Test-RaspberryPiConnection {
    param([switch]$Silent)

    $url = "http://${RaspberryPiIP}:${Port}/"

    try {
        $response = Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 3
        return $true
    }
    catch {
        return $false
    }
}

function Draw-InitialUI {
    Clear-Host
    $row = 0

    # Banner
    Write-Host ""
    $row++
    Write-Host "  +====================================================================+" -ForegroundColor Cyan
    $row++
    Write-Host "  |              MS Teams Status Push Client                          |" -ForegroundColor Cyan
    $row++
    Write-Host "  +====================================================================+" -ForegroundColor Cyan
    $row++
    Write-Host ""
    $row++

    # Configuration box
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    Write-Host "  |  Configuration                                                     |" -ForegroundColor DarkGray
    $row++
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    Write-Host "  |  Raspberry Pi:  " -NoNewline -ForegroundColor DarkGray
    Write-Host "$RaspberryPiIP".PadRight(20) -NoNewline -ForegroundColor White
    Write-Host "Port: " -NoNewline -ForegroundColor DarkGray
    Write-Host "$Port".PadRight(10) -NoNewline -ForegroundColor White
    Write-Host "          |" -ForegroundColor DarkGray
    $row++
    Write-Host "  |  Poll Interval: " -NoNewline -ForegroundColor DarkGray
    Write-Host "${PollInterval}s".PadRight(51) -NoNewline -ForegroundColor White
    Write-Host "|" -ForegroundColor DarkGray
    $row++
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    Write-Host ""
    $row++

    # Services box
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    Write-Host "  |  Raspberry Pi Services                                             |" -ForegroundColor DarkGray
    $row++
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    Write-Host "  |  Web Dashboard:   " -NoNewline -ForegroundColor DarkGray
    Write-Host "http://${RaspberryPiIP}:5000".PadRight(49) -NoNewline -ForegroundColor Cyan
    Write-Host "|" -ForegroundColor DarkGray
    $row++
    Write-Host "  |  Status API:      " -NoNewline -ForegroundColor DarkGray
    Write-Host "http://${RaspberryPiIP}:${Port}/status".PadRight(49) -NoNewline -ForegroundColor Cyan
    Write-Host "|" -ForegroundColor DarkGray
    $row++
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    Write-Host ""
    $row++

    # Current Status box
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    Write-Host "  |  Current Status                                                    |" -ForegroundColor DarkGray
    $row++
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    $script:CurrentStatusRow = $row
    Write-Host "  |  [??] Unknown                                                      |" -ForegroundColor DarkGray
    $row++
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    Write-Host ""
    $row++

    # History box
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    Write-Host "  |  Recent Changes                                                    |" -ForegroundColor DarkGray
    $row++
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    $script:HistoryStartRow = $row
    for ($i = 0; $i -lt $script:MaxHistory; $i++) {
        Write-Host "  |  -                                                                 |" -ForegroundColor DarkGray
        $row++
    }
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    Write-Host ""
    $row++

    # Connection status
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    $script:ConnectionRow = $row
    Write-Host "  |  Connection: Checking...                                           |" -ForegroundColor DarkGray
    $row++
    Write-Host "  +--------------------------------------------------------------------+" -ForegroundColor DarkGray
    $row++
    Write-Host ""
    $row++

    # Last poll time
    $script:LastPollRow = $row
    Write-Host "  Last poll: --:--:--    | Next in: ${PollInterval}s    | Press Ctrl+C to stop" -ForegroundColor DarkGray

    # Hide cursor
    [Console]::CursorVisible = $false
}

# Main execution
Draw-InitialUI

# Test initial connection
$connectionOk = Test-RaspberryPiConnection -Silent
if ($connectionOk) {
    $script:ConnectionStatus = "Connected"
    $script:LastSuccessfulSend = Get-Date
}
Update-ConnectionStatus -Connected $connectionOk

# Main monitoring loop
$consecutiveErrors = 0
$maxConsecutiveErrors = 5

try {
    while ($true) {
        try {
            $status = Get-TeamsStatus
            Write-Debug-Log "Retrieved status: $($status.Availability)"

            # Always update current status display
            Update-CurrentStatus -Status $status.Availability

            # Check if status changed
            if ($status.Availability -ne $script:LastStatus -or $status.Activity -ne $script:LastActivity) {

                # Send update to Raspberry Pi
                $sent = Send-StatusUpdate -Availability $status.Availability -Activity $status.Activity

                if ($sent) {
                    $script:UpdateCount++
                    $script:ConnectionStatus = "Connected"
                    $script:LastSuccessfulSend = Get-Date
                    $consecutiveErrors = 0
                }
                else {
                    $script:ConnectionStatus = "Disconnected"
                    $consecutiveErrors++
                }

                # Add to history
                Add-StatusToHistory -Status $status.Availability -Sent $sent
                Update-History
                Update-ConnectionStatus -Connected $sent

                $script:LastStatus = $status.Availability
                $script:LastActivity = $status.Activity
            }

            # Check for too many consecutive errors - try reconnecting
            if ($consecutiveErrors -ge $maxConsecutiveErrors) {
                $connectionOk = Test-RaspberryPiConnection -Silent
                Update-ConnectionStatus -Connected $connectionOk
                $consecutiveErrors = 0
            }

            Update-LastPoll
            Start-Sleep -Seconds $PollInterval
        }
        catch {
            Write-Debug-Log "Error: $($_.Exception.Message)"
            Start-Sleep -Seconds $PollInterval
        }
    }
}
finally {
    # Restore cursor on exit
    [Console]::CursorVisible = $true
    [Console]::SetCursorPosition(0, $script:LastPollRow + 3)
    Write-Host ""
    Write-Host "  Stopped." -ForegroundColor Yellow
}
