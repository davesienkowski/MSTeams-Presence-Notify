# Check Teams Log Locations
# This script helps identify which version of Teams you have and where the logs are

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Teams Log Location Checker" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Define paths
$NewTeamsLogPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs\"
$ClassicTeamsLogPath = "$env:APPDATA\Microsoft\Teams\logs.txt"

Write-Host "Checking New Teams (Teams 2.0) location:" -ForegroundColor Yellow
Write-Host "  Path: $NewTeamsLogPath" -ForegroundColor Gray
if (Test-Path $NewTeamsLogPath)
{
    Write-Host "  Status: EXISTS" -ForegroundColor Green

    # Get log files
    $logFiles = Get-ChildItem -Path $NewTeamsLogPath -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5

    if ($logFiles)
    {
        Write-Host "  Recent log files:" -ForegroundColor Green
        foreach ($file in $logFiles)
        {
            Write-Host "    - $($file.Name) (Modified: $($file.LastWriteTime))" -ForegroundColor White
        }

        # Check the most recent file for status patterns
        $latestFile = $logFiles[0]
        Write-Host ""
        Write-Host "  Checking latest file for status information..." -ForegroundColor Yellow
        $content = Get-Content $latestFile.FullName -Tail 1000 -ErrorAction SilentlyContinue

        $statusMatches = $content | Select-String -Pattern "availability:\s*(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)" -AllMatches
        if ($statusMatches)
        {
            Write-Host "  Found status information: YES" -ForegroundColor Green
            Write-Host "  Sample matches:" -ForegroundColor Green
            $statusMatches | Select-Object -First 3 | ForEach-Object {
                Write-Host "    $($_.Line.Trim())" -ForegroundColor White
            }
        }
        else
        {
            Write-Host "  Found status information: NO" -ForegroundColor Red
        }
    }
    else
    {
        Write-Host "  No log files found!" -ForegroundColor Red
    }
}
else
{
    Write-Host "  Status: NOT FOUND" -ForegroundColor Red
}

Write-Host ""
Write-Host "Checking Classic Teams location:" -ForegroundColor Yellow
Write-Host "  Path: $ClassicTeamsLogPath" -ForegroundColor Gray
if (Test-Path $ClassicTeamsLogPath)
{
    Write-Host "  Status: EXISTS" -ForegroundColor Green

    $fileInfo = Get-Item $ClassicTeamsLogPath
    Write-Host "  File size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor White
    Write-Host "  Modified: $($fileInfo.LastWriteTime)" -ForegroundColor White

    # Check for status patterns
    Write-Host ""
    Write-Host "  Checking for status information..." -ForegroundColor Yellow
    $content = Get-Content $ClassicTeamsLogPath -Tail 1000 -ErrorAction SilentlyContinue
    $statusMatches = $content | Select-String -Pattern "NewActivity|Setting the taskbar overlay icon" -AllMatches

    if ($statusMatches)
    {
        Write-Host "  Found status information: YES" -ForegroundColor Green
        Write-Host "  Sample matches:" -ForegroundColor Green
        $statusMatches | Select-Object -First 3 | ForEach-Object {
            Write-Host "    $($_.Line.Trim())" -ForegroundColor White
        }
    }
    else
    {
        Write-Host "  Found status information: NO" -ForegroundColor Red
    }
}
else
{
    Write-Host "  Status: NOT FOUND" -ForegroundColor Red
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Recommendation:" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

if (Test-Path $NewTeamsLogPath)
{
    Write-Host "Use NEW TEAMS (Teams 2.0) - this is the recommended version" -ForegroundColor Green
    Write-Host "The script should automatically use this location." -ForegroundColor Green
}
elseif (Test-Path $ClassicTeamsLogPath)
{
    Write-Host "Use CLASSIC TEAMS" -ForegroundColor Yellow
    Write-Host "The script should automatically fall back to this location." -ForegroundColor Yellow
}
else
{
    Write-Host "ERROR: No Teams installation found!" -ForegroundColor Red
    Write-Host "Please ensure Microsoft Teams is installed and has been run at least once." -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
