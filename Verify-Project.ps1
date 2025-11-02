# Project Verification Script
# Verifies all files are in place and ready to use
# PowerShell 5.1+ Compatible

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MS Teams Presence PyPortal - Project Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = $PSScriptRoot
Write-Host "Project Location: $ProjectRoot" -ForegroundColor Gray
Write-Host ""

$script:AllChecks = @()

# Function to check file
function Test-ProjectFile
{
    param(
        [string]$Path,
        [string]$Description
    )

    $FullPath = Join-Path -Path $ProjectRoot -ChildPath $Path
    if (Test-Path -Path $FullPath)
    {
        Write-Host "  [OK] $Description" -ForegroundColor Green
        $script:AllChecks += $true
        return $true
    }
    else
    {
        Write-Host "  [MISSING] $Description" -ForegroundColor Red
        Write-Host "    Expected: $FullPath" -ForegroundColor Yellow
        $script:AllChecks += $false
        return $false
    }
}

# Check core documentation
Write-Host "[1/5] Checking Documentation..." -ForegroundColor Yellow
Test-ProjectFile "README.md" "Main README" | Out-Null
Test-ProjectFile "docs\PROJECT_PLAN.md" "Complete project plan" | Out-Null
Test-ProjectFile "docs\QUICK_START_POWERSHELL.md" "PowerShell quick start guide" | Out-Null
Test-ProjectFile "docs\ALTERNATIVE_METHODS.md" "Alternative methods documentation" | Out-Null

# Check PowerShell service
Write-Host ""
Write-Host "[2/5] Checking PowerShell Service..." -ForegroundColor Yellow
Test-ProjectFile "powershell_service\TeamsStatusServer.ps1" "Main server script" | Out-Null
Test-ProjectFile "powershell_service\Test-TeamsStatus.ps1" "Diagnostics script" | Out-Null
Test-ProjectFile "powershell_service\README.md" "PowerShell service documentation" | Out-Null

# Check computer service (Python - optional for Graph API)
Write-Host ""
Write-Host "[3/5] Checking Computer Service (Graph API - Optional)..." -ForegroundColor Yellow
Test-ProjectFile "computer_service\__init__.py" "Python package init" | Out-Null
Test-ProjectFile "computer_service\main.py" "Python main service" | Out-Null
Test-ProjectFile "requirements.txt" "Python dependencies" | Out-Null
Test-ProjectFile "env.example" "Environment template" | Out-Null

# Check configuration
Write-Host ""
Write-Host "[4/5] Checking Configuration..." -ForegroundColor Yellow
Test-ProjectFile ".gitignore" "Git ignore file" | Out-Null

$EnvPath = Join-Path -Path $ProjectRoot -ChildPath ".env"
if (Test-Path -Path $EnvPath)
{
    Write-Host "  [OK] .env file exists (credentials configured)" -ForegroundColor Green
    $script:AllChecks += $true
}
else
{
    Write-Host "  [INFO] .env file not found (expected - will create when needed)" -ForegroundColor Cyan
}

# Check PyPortal directory
Write-Host ""
Write-Host "[5/5] Checking PyPortal Structure..." -ForegroundColor Yellow
$PyPortalPath = Join-Path -Path $ProjectRoot -ChildPath "pyportal"
if (Test-Path -Path $PyPortalPath)
{
    Write-Host "  [OK] PyPortal directory exists" -ForegroundColor Green
    $script:AllChecks += $true
}
else
{
    Write-Host "  [INFO] PyPortal directory not yet created (will create with code)" -ForegroundColor Cyan
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$PassCount = ($AllChecks | Where-Object { $_ -eq $true }).Count
$TotalCount = $AllChecks.Count

Write-Host "Files Verified: $PassCount / $TotalCount" -ForegroundColor White

if ($PassCount -eq $TotalCount)
{
    Write-Host ""
    Write-Host "[OK] All critical files are present!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Project Status: READY" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. cd powershell_service" -ForegroundColor White
    Write-Host "  2. powershell -ExecutionPolicy Bypass -File Test-TeamsStatus.ps1" -ForegroundColor White
    Write-Host "  3. powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1" -ForegroundColor White
    Write-Host ""
}
else
{
    Write-Host ""
    Write-Host "[WARNING] Some files are missing" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You may need to recreate missing files." -ForegroundColor White
    Write-Host ""
}

# PowerShell version check
Write-Host "System Information:" -ForegroundColor Yellow
Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "  OS: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor Gray
Write-Host "  Computer: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "  User: $env:USERNAME" -ForegroundColor Gray
Write-Host ""

# Check if Teams is installed
Write-Host "Teams Installation Check:" -ForegroundColor Yellow
$TeamsProcess = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue
if ($TeamsProcess)
{
    Write-Host "  [OK] Microsoft Teams is running" -ForegroundColor Green
}
else
{
    Write-Host "  [INFO] Microsoft Teams is not currently running" -ForegroundColor Cyan
}

$NewTeamsPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe"
$ClassicTeamsPath = "$env:APPDATA\Microsoft\Teams"

if (Test-Path -Path $NewTeamsPath)
{
    Write-Host "  [OK] New Teams detected" -ForegroundColor Green
}
elseif (Test-Path -Path $ClassicTeamsPath)
{
    Write-Host "  [OK] Classic Teams detected (support ends July 2025)" -ForegroundColor Yellow
}
else
{
    Write-Host "  [WARNING] Teams installation not detected" -ForegroundColor Yellow
}

Write-Host ""
