# Teams Status HTTP Client for Feather M0 WiFi
# Monitors MS Teams log files and sends status to Feather M0 WiFi HTTP server
#
# Architecture: Work PC (HTTP Client) → Feather M0 WiFi (HTTP Server)
# This works even when local devices can't access Work PC (corporate network isolation)

param(
    [string]$FeatherIP = "192.168.1.100",  # Change to your Feather's IP address
    [int]$FeatherPort = 80,
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

# Status mapping (maps Teams status to numeric codes for Feather)
$StatusCodeMap = @{
    "Available" = 0
    "Busy" = 1
    "Away" = 2
    "BeRightBack" = 3
    "DoNotDisturb" = 4
    "Focusing" = 5
    "Presenting" = 6
    "InAMeeting" = 7
    "InACall" = 8
    "Offline" = 9
    "Unknown" = 10
}

# Current status tracking
$script:CurrentStatus = @{
    availability = "Unknown"
    activity = "Unknown"
    statusCode = 10
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
                statusCode = 9
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
            statusCode = 10
            detected = $true
        }

        # Parse availability status from log patterns (priority order)
        if ($LogContent -match "SetBadge Setting badge:.*doNotDisturb|Do not disturb") {
            $result.availability = "DoNotDisturb"
            $result.statusCode = 4
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*focusing") {
            $result.availability = "Focusing"
            $result.statusCode = 5
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*presenting") {
            $result.availability = "Presenting"
            $result.statusCode = 6
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*inameeting|InAMeeting") {
            $result.availability = "InAMeeting"
            $result.statusCode = 7
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*busy") {
            $result.availability = "Busy"
            $result.statusCode = 1
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*away") {
            $result.availability = "Away"
            $result.statusCode = 2
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*berightback|BeRightBack") {
            $result.availability = "BeRightBack"
            $result.statusCode = 3
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*available") {
            $result.availability = "Available"
            $result.statusCode = 0
        }
        elseif ($LogContent -match "SetBadge Setting badge:.*offline") {
            $result.availability = "Offline"
            $result.statusCode = 9
        }

        # Check for call activity
        if ($LogContent -match "NotifyCallActive|NotifyCallAccepted") {
            $result.activity = "InACall"
            $result.statusCode = 8  # Override with InACall
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

# Function to send status to Feather M0 WiFi
function Send-StatusToFeather {
    param($StatusCode)

    try {
        $url = "http://${FeatherIP}:${FeatherPort}/status"
        $body = @{ status = $StatusCode } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri $url `
                                      -Method POST `
                                      -Body $body `
                                      -ContentType "application/json" `
                                      -TimeoutSec 5 `
                                      -ErrorAction Stop

        if ($Debug) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Sent status $StatusCode to Feather successfully" -ForegroundColor Green
        }

        return $true
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Failed to send to Feather: $_" -ForegroundColor Red
        return $false
    }
}

# Start monitoring
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Teams Status Client for Feather M0 WiFi" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Feather IP: $FeatherIP" -ForegroundColor White
Write-Host "  Feather Port: $FeatherPort" -ForegroundColor White
Write-Host "  Check Interval: $CheckInterval seconds" -ForegroundColor White
Write-Host "  Log Path: $LogPath" -ForegroundColor White
Write-Host "  Debug Mode: $Debug`n" -ForegroundColor White

# Test connection to Feather
Write-Host "Testing connection to Feather M0 WiFi..." -ForegroundColor Cyan
try {
    $testUrl = "http://${FeatherIP}:${FeatherPort}/health"
    $health = Invoke-RestMethod -Uri $testUrl -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✓ Connected to Feather M0 WiFi successfully!" -ForegroundColor Green
    Write-Host "  IP: $($health.ip)" -ForegroundColor White
    Write-Host "  Output Device: $($health.output)`n" -ForegroundColor White
}
catch {
    Write-Host "✗ Cannot reach Feather M0 WiFi at $FeatherIP" -ForegroundColor Red
    Write-Host "`nPlease check:" -ForegroundColor Yellow
    Write-Host "1. Feather M0 WiFi is powered on" -ForegroundColor White
    Write-Host "2. Feather is connected to WiFi (check serial console)" -ForegroundColor White
    Write-Host "3. IP address is correct (check serial console or visit http://$FeatherIP in browser)" -ForegroundColor White
    Write-Host "4. Both devices are on the same network" -ForegroundColor White
    Write-Host "5. Firewall allows outbound connections`n" -ForegroundColor White
    exit 1
}

# Initial status check
Write-Host "Performing initial status check..." -ForegroundColor Cyan
$newStatus = Get-TeamsStatus -LogPath $LogPath -UseNewTeams $UseNewTeams

if ($newStatus.detected) {
    $script:CurrentStatus.availability = $newStatus.availability
    $script:CurrentStatus.activity = $newStatus.activity
    $script:CurrentStatus.statusCode = $newStatus.statusCode
    $script:CurrentStatus.lastUpdate = Get-Date

    Write-Host "Initial status: $($newStatus.availability) (code: $($newStatus.statusCode))" -ForegroundColor Green
    Send-StatusToFeather -StatusCode $newStatus.statusCode
}
else {
    Write-Host "Could not detect status from logs" -ForegroundColor Yellow
}

Write-Host "`nMonitoring started. Press Ctrl+C to stop." -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

# Main monitoring loop
$requestCount = 0

while ($true) {
    Start-Sleep -Seconds $CheckInterval

    # Get current status
    $newStatus = Get-TeamsStatus -LogPath $LogPath -UseNewTeams $UseNewTeams

    if ($newStatus.detected) {
        $availability = $newStatus.availability
        $statusCode = $newStatus.statusCode

        # Only send if status changed
        if ($statusCode -ne $script:CurrentStatus.statusCode) {
            $requestCount++

            # Update global status
            $script:CurrentStatus.availability = $availability
            $script:CurrentStatus.statusCode = $statusCode
            $script:CurrentStatus.lastUpdate = Get-Date

            # Send to Feather
            $success = Send-StatusToFeather -StatusCode $statusCode

            if ($success) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Status changed: $availability (code: $statusCode)" -ForegroundColor Cyan
            }
        }
        elseif ($Debug) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Status unchanged: $availability" -ForegroundColor Gray
        }
    }
    else {
        if ($Debug) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Could not detect status from logs" -ForegroundColor Yellow
        }
    }
}
