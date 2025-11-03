# Test Log Pattern Matching
# This script checks the Teams logs directly to see what status information is available

$NewTeamsLogPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs\"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Teams Log Pattern Test" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Get the most recent log file
$logFiles = Get-ChildItem -Path $NewTeamsLogPath -Filter "MSTeams_*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

if ($logFiles) {
    $latestFile = $logFiles[0]
    Write-Host "Reading log file: $($latestFile.Name)" -ForegroundColor Green
    Write-Host "Last modified: $($latestFile.LastWriteTime)" -ForegroundColor Gray
    Write-Host ""

    # Read last 2000 lines
    $content = Get-Content $latestFile.FullName -Tail 2000 -ErrorAction SilentlyContinue

    # Look for status-related lines
    Write-Host "Searching for status-related patterns..." -ForegroundColor Yellow
    Write-Host ""

    # Pattern 1: availability
    Write-Host "Pattern 1: 'availability:'" -ForegroundColor Cyan
    $availabilityLines = $content | Select-String -Pattern "availability:\s*(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)" -AllMatches
    if ($availabilityLines) {
        Write-Host "  Found $($availabilityLines.Count) matches" -ForegroundColor Green
        Write-Host "  Most recent 3 matches:" -ForegroundColor Green
        $availabilityLines | Select-Object -Last 3 | ForEach-Object {
            Write-Host "    $($_.Line)" -ForegroundColor White
        }
    } else {
        Write-Host "  No matches found" -ForegroundColor Red
    }
    Write-Host ""

    # Pattern 2: SetBadge status
    Write-Host "Pattern 2: 'status' (SetBadge)" -ForegroundColor Cyan
    $statusLines = $content | Select-String -Pattern "status\s+(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)" -AllMatches
    if ($statusLines) {
        Write-Host "  Found $($statusLines.Count) matches" -ForegroundColor Green
        Write-Host "  Most recent 3 matches:" -ForegroundColor Green
        $statusLines | Select-Object -Last 3 | ForEach-Object {
            Write-Host "    $($_.Line)" -ForegroundColor White
        }
    } else {
        Write-Host "  No matches found" -ForegroundColor Red
    }
    Write-Host ""

    # Pattern 3: UserDataCrossCloudModule
    Write-Host "Pattern 3: 'UserDataCrossCloudModule'" -ForegroundColor Cyan
    $userDataLines = $content | Select-String -Pattern "UserDataCrossCloudModule" -AllMatches
    if ($userDataLines) {
        Write-Host "  Found $($userDataLines.Count) matches" -ForegroundColor Green
        Write-Host "  Most recent 3 matches:" -ForegroundColor Green
        $userDataLines | Select-Object -Last 3 | ForEach-Object {
            Write-Host "    $($_.Line.Substring(0, [Math]::Min(200, $_.Line.Length)))" -ForegroundColor White
        }
    } else {
        Write-Host "  No matches found" -ForegroundColor Red
    }
    Write-Host ""

    # Pattern 4: UserPresenceAction
    Write-Host "Pattern 4: 'UserPresenceAction'" -ForegroundColor Cyan
    $presenceLines = $content | Select-String -Pattern "UserPresenceAction" -AllMatches
    if ($presenceLines) {
        Write-Host "  Found $($presenceLines.Count) matches" -ForegroundColor Green
        Write-Host "  Most recent 3 matches:" -ForegroundColor Green
        $presenceLines | Select-Object -Last 3 | ForEach-Object {
            Write-Host "    $($_.Line.Substring(0, [Math]::Min(200, $_.Line.Length)))" -ForegroundColor White
        }
    } else {
        Write-Host "  No matches found" -ForegroundColor Red
    }
    Write-Host ""

    # Test the combined filter
    Write-Host "Combined Filter Test (what the script actually uses):" -ForegroundColor Cyan
    $statusLines = $content | Where-Object {
        $_ -match "UserDataCrossCloudModule|UserPresenceAction|SetBadge.*status|StatusIndicatorStateService|NewActivity"
    }

    if ($statusLines) {
        $recentStatus = @($statusLines | Select-Object -Last 10)
        Write-Host "  Found $($statusLines.Count) total status-related lines" -ForegroundColor Green
        Write-Host "  Most recent 10 lines:" -ForegroundColor Green
        for ($i = $recentStatus.Count - 1; $i -ge 0; $i--) {
            $line = $recentStatus[$i]
            $preview = if ($line.Length -gt 200) { $line.Substring(0, 200) } else { $line }
            Write-Host "    [$($recentStatus.Count - $i)]: $preview" -ForegroundColor White
        }
    } else {
        Write-Host "  No matches found" -ForegroundColor Red
    }

} else {
    Write-Host "ERROR: No Teams log files found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
