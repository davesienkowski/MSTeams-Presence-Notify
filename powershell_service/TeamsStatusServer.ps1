# Teams Status HTTP Server for PyPortal
# Based on EBOOZ/TeamsStatus - Modified for PyPortal integration
# Monitors MS Teams log files and serves status via HTTP on port 8080

param(
    [int]$Port = 8080,
    [int]$CheckInterval = 5,
    [switch]$Debug
)

# Configuration
$LocalUsername = $env:USERNAME
$TeamsLogPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs\"

# Fallback for Classic Teams (will be removed July 2025)
$ClassicTeamsLogPath = "$env:APPDATA\Microsoft\Teams\logs.txt"

# Check which Teams version is installed
$UseNewTeams = Test-Path $TeamsLogPath
$UseClassicTeams = Test-Path $ClassicTeamsLogPath

if (-not $UseNewTeams -and -not $UseClassicTeams) {
    Write-Host "ERROR: Could not find Teams log directory!" -ForegroundColor Red
    Write-Host "New Teams path: $TeamsLogPath" -ForegroundColor Yellow
    Write-Host "Classic Teams path: $ClassicTeamsLogPath" -ForegroundColor Yellow
    Write-Host "`nPlease ensure Microsoft Teams is installed and has been run at least once." -ForegroundColor Yellow
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
    "Focusing" = "#800080"        # Purple (treated as DND)
    "Presenting" = "#FF0000"      # Red (like busy)
    "InAMeeting" = "#FF0000"      # Red (like busy)
    "InACall" = "#FF0000"         # Red (like busy)
    "Offline" = "#808080"         # Gray
    "Unknown" = "#FFFFFF"         # White
}

# Shared status object
$script:CurrentStatus = @{
    availability = "Unknown"
    activity = "Unknown"
    color = "#FFFFFF"
    lastUpdate = Get-Date
}

# Function to parse Teams logs
function Get-TeamsStatus {
    param($LogPath, $UseNewTeams)

    try {
        # Check if Teams is running
        $TeamsProcess = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue

        if (-not $TeamsProcess) {
            return @{
                availability = "Offline"
                activity = "Offline"
                detected = $true
            }
        }

        if ($UseNewTeams) {
            # New Teams: Read from latest log file
            $LogFiles = Get-ChildItem -Path $LogPath -Filter "*.log" -ErrorAction SilentlyContinue |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 3

            if (-not $LogFiles) {
                return @{ detected = $false }
            }

            # Read last 1000 lines from most recent logs
            $LogContent = ""
            foreach ($LogFile in $LogFiles) {
                $LogContent += Get-Content -Path $LogFile.FullName -Tail 500 -ErrorAction SilentlyContinue | Out-String
            }
        }
        else {
            # Classic Teams: Read from logs.txt
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

        # Parse availability status from log patterns
        # Priority order: specific states first, then general
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

        # Also check SetTaskbarIconOverlay patterns as fallback
        if ($result.availability -eq "Unknown") {
            if ($LogContent -match "SetTaskbarIconOverlay.*available") {
                $result.availability = "Available"
            }
            elseif ($LogContent -match "SetTaskbarIconOverlay.*busy") {
                $result.availability = "Busy"
            }
            elseif ($LogContent -match "SetTaskbarIconOverlay.*away") {
                $result.availability = "Away"
            }
        }

        # Parse activity (call status)
        if ($LogContent -match "NotifyCallActive|NotifyCallAccepted") {
            $result.activity = "InACall"
        }
        elseif ($LogContent -match "reportIncomingCall") {
            $result.activity = "IncomingCall"
        }
        elseif ($LogContent -match "RequestNewOutgoingCallWithOptions") {
            $result.activity = "OutgoingCall"
        }
        elseif ($LogContent -match "NotifyCallEnded") {
            $result.activity = "Available"
        }
        else {
            # Default activity to availability if no call detected
            $result.activity = $result.availability
        }

        return $result
    }
    catch {
        Write-Host "Error parsing Teams logs: $_" -ForegroundColor Red
        return @{ detected = $false }
    }
}

# Function to update status
function Update-Status {
    $newStatus = Get-TeamsStatus -LogPath $LogPath -UseNewTeams $UseNewTeams

    if ($newStatus.detected) {
        $availability = $newStatus.availability
        $activity = $newStatus.activity

        # Get color for current availability
        $color = $ColorMap[$availability]
        if (-not $color) { $color = "#FFFFFF" }

        # Update global status
        $script:CurrentStatus.availability = $availability
        $script:CurrentStatus.activity = $activity
        $script:CurrentStatus.color = $color
        $script:CurrentStatus.lastUpdate = Get-Date

        if ($Debug) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Status: $availability | Activity: $activity | Color: $color" -ForegroundColor Cyan
        }
    }
    else {
        if ($Debug) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Could not detect status from logs" -ForegroundColor Yellow
        }
    }
}

# Start HTTP listener
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Teams Status HTTP Server for PyPortal" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Port: $Port" -ForegroundColor White
Write-Host "  Check Interval: $CheckInterval seconds" -ForegroundColor White
Write-Host "  Log Path: $LogPath" -ForegroundColor White
Write-Host "  Debug Mode: $Debug`n" -ForegroundColor White

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Prefixes.Add("http://+:$Port/")  # Allow external connections

try {
    $listener.Start()
    Write-Host "✓ HTTP Server started on http://localhost:$Port/" -ForegroundColor Green
    Write-Host "✓ PyPortal can connect to http://<your-ip>:$Port/status" -ForegroundColor Green
    Write-Host "`nPress Ctrl+C to stop the server`n" -ForegroundColor Yellow
    Write-Host "========================================`n" -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: Could not start HTTP listener on port $Port" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check if port $Port is already in use: netstat -ano | findstr :$Port" -ForegroundColor White
    Write-Host "2. Try running as Administrator" -ForegroundColor White
    Write-Host "3. Try a different port: -Port 8081" -ForegroundColor White
    exit 1
}

# Initial status check
Write-Host "Performing initial status check..." -ForegroundColor Cyan
Update-Status
Write-Host "Initial status: $($script:CurrentStatus.availability)`n" -ForegroundColor Green

# Background job for continuous status monitoring
$MonitorJob = Start-Job -ScriptBlock {
    param($LogPath, $UseNewTeams, $CheckInterval, $Debug)

    function Get-TeamsStatus {
        param($LogPath, $UseNewTeams)

        try {
            $TeamsProcess = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue

            if (-not $TeamsProcess) {
                return @{ availability = "Offline"; activity = "Offline"; detected = $true }
            }

            if ($UseNewTeams) {
                $LogFiles = Get-ChildItem -Path $LogPath -Filter "*.log" -ErrorAction SilentlyContinue |
                            Sort-Object LastWriteTime -Descending |
                            Select-Object -First 3

                if (-not $LogFiles) { return @{ detected = $false } }

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

            $result = @{ availability = "Unknown"; activity = "Unknown"; detected = $true }

            # Parse status (same logic as main function)
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
            return @{ detected = $false }
        }
    }

    while ($true) {
        Start-Sleep -Seconds $CheckInterval
        $newStatus = Get-TeamsStatus -LogPath $LogPath -UseNewTeams $UseNewTeams
        if ($newStatus.detected) {
            $newStatus | ConvertTo-Json -Compress
        }
    }
} -ArgumentList $LogPath, $UseNewTeams, $CheckInterval, $Debug

Write-Host "Background monitoring started (checking every $CheckInterval seconds)`n" -ForegroundColor Green

# HTTP request handler loop - simple blocking approach for PowerShell 5.1 compatibility
$requestCount = 0

# Use a runspace to handle requests without blocking status updates
$syncHash = [hashtable]::Synchronized(@{
    Listener = $listener
    CurrentStatus = $script:CurrentStatus
    ColorMap = $ColorMap
    MonitorJob = $MonitorJob
    RequestCount = 0
    ShouldStop = $false
})

$requestHandler = {
    param($syncHash)

    while (-not $syncHash.ShouldStop) {
        try {
            # Update status from background job
            $jobOutput = Receive-Job -Job $syncHash.MonitorJob -ErrorAction SilentlyContinue
            if ($jobOutput) {
                try {
                    $update = $jobOutput | ConvertFrom-Json
                    $syncHash.CurrentStatus.availability = $update.availability
                    $syncHash.CurrentStatus.activity = $update.activity
                    $syncHash.CurrentStatus.color = $syncHash.ColorMap[$update.availability]
                    if (-not $syncHash.CurrentStatus.color) { $syncHash.CurrentStatus.color = "#FFFFFF" }
                    $syncHash.CurrentStatus.lastUpdate = Get-Date
                }
                catch {
                    # Ignore parsing errors
                }
            }

            # Get request (this blocks until a request arrives)
            if ($syncHash.Listener.IsListening) {
                $context = $syncHash.Listener.GetContext()
                $request = $context.Request
                $response = $context.Response

                $syncHash.RequestCount++

                try {
                    if ($request.Url.AbsolutePath -eq "/status") {
                        # Build JSON response
                        $json = @{
                            availability = $syncHash.CurrentStatus.availability
                            activity = $syncHash.CurrentStatus.activity
                            color = $syncHash.CurrentStatus.color
                        } | ConvertTo-Json -Compress

                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                        $response.ContentLength64 = $buffer.Length
                        $response.ContentType = "application/json"
                        $response.AddHeader("Access-Control-Allow-Origin", "*")
                        $response.StatusCode = 200
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                        $response.OutputStream.Close()

                        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Request #$($syncHash.RequestCount) : Status served ($($syncHash.CurrentStatus.availability))" -ForegroundColor Green
                    }
                    elseif ($request.Url.AbsolutePath -eq "/health") {
                        # Health check endpoint
                        $json = @{
                            status = "healthy"
                            uptime = ((Get-Date) - $syncHash.CurrentStatus.lastUpdate).TotalSeconds
                            requests = $syncHash.RequestCount
                        } | ConvertTo-Json -Compress

                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                        $response.ContentLength64 = $buffer.Length
                        $response.ContentType = "application/json"
                        $response.StatusCode = 200
                        $response.OutputStream.Write($buffer, 0, $buffer.Length)
                        $response.OutputStream.Close()
                    }
                    else {
                        # 404 for other paths
                        $response.StatusCode = 404
                        $response.Close()
                    }
                }
                catch {
                    Write-Host "Error sending response: $_" -ForegroundColor Red
                    try { $response.Close() } catch {}
                }
            }
        }
        catch {
            if ($_.Exception.Message -notlike "*operation was canceled*" -and
                $_.Exception.Message -notlike "*The I/O operation has been aborted*") {
                Write-Host "Request error: $_" -ForegroundColor Red
            }
        }
    }
}

# Start request handler in background runspace
$PowerShell = [powershell]::Create()
$PowerShell.AddScript($requestHandler).AddArgument($syncHash) | Out-Null
$AsyncHandle = $PowerShell.BeginInvoke()

Write-Host "HTTP request handler started. Waiting for requests...`n" -ForegroundColor Green

# Main loop just waits for Ctrl+C
try {
    while ($true) {
        Start-Sleep -Seconds 1
        if (-not $listener.IsListening) { break }
    }
}
catch {
    # Ctrl+C pressed
}

# Cleanup
Write-Host "`nShutting down..." -ForegroundColor Yellow
$syncHash.ShouldStop = $true
Stop-Job $MonitorJob
Remove-Job $MonitorJob
$listener.Stop()
$PowerShell.Stop()
$PowerShell.Dispose()
Write-Host "Server stopped." -ForegroundColor Green
