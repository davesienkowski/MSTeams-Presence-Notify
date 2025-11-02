# Build.ps1
# Builds Teams BLE Transmitter as a standalone .exe

param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [switch]$SingleFile = $true,
    [switch]$SelfContained = $true,
    [switch]$Run = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Teams BLE Transmitter Builder" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check for .NET SDK
Write-Host "Checking .NET SDK..." -ForegroundColor Yellow
try {
    $dotnetVersion = dotnet --version
    Write-Host "[OK] .NET SDK: $dotnetVersion" -ForegroundColor Green
} catch {
    Write-Host "[X] .NET SDK not found" -ForegroundColor Red
    Write-Host "`nPlease install .NET 6.0 SDK from:" -ForegroundColor Yellow
    Write-Host "https://dotnet.microsoft.com/download/dotnet/6.0" -ForegroundColor Cyan
    exit 1
}

# Get project directory
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "`nBuilding project..." -ForegroundColor Yellow
Write-Host "  Configuration: $Configuration"
Write-Host "  Single File: $SingleFile"
Write-Host "  Self Contained: $SelfContained"
Write-Host ""

# Build command
$buildArgs = @(
    "publish"
    "-c", $Configuration
    "-r", "win-x64"
)

if ($SelfContained) {
    $buildArgs += "--self-contained", "true"
}

if ($SingleFile) {
    $buildArgs += "-p:PublishSingleFile=true"
}

# Execute build
Push-Location $ProjectDir
try {
    & dotnet @buildArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[OK] Build successful!" -ForegroundColor Green

        # Find the output .exe
        $outputPath = Join-Path $ProjectDir "bin\$Configuration\net6.0-windows10.0.19041.0\win-x64\publish\TeamsBLETransmitter.exe"

        if (Test-Path $outputPath) {
            $fileInfo = Get-Item $outputPath
            $sizeKB = [math]::Round($fileInfo.Length / 1KB, 2)

            Write-Host "`nOutput:" -ForegroundColor Yellow
            Write-Host "  Path: $outputPath"
            Write-Host "  Size: $sizeKB KB"

            # Run if requested
            if ($Run) {
                Write-Host "`nRunning application..." -ForegroundColor Cyan
                & $outputPath
            } else {
                Write-Host "`nTo run:" -ForegroundColor Yellow
                Write-Host "  $outputPath" -ForegroundColor Cyan
            }
        } else {
            Write-Host "[!] Warning: Output file not found at expected location" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[X] Build failed" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

Write-Host ""
