#!/usr/bin/env pwsh
# Build script for Teams WiFi Transmitter

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building Teams WiFi Transmitter" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if .NET 8.0 SDK is installed
$dotnetVersion = dotnet --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] .NET SDK not found!" -ForegroundColor Red
    Write-Host "Download from: https://dotnet.microsoft.com/download" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Found .NET SDK version: $dotnetVersion`n" -ForegroundColor Green

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
dotnet clean -c Release -v quiet

# Build and publish
Write-Host "Building Release version...`n" -ForegroundColor Yellow
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:PublishReadyToRun=true

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Build successful!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green

    $exePath = "bin\Release\net8.0-windows10.0.22000.0\win-x64\publish\TeamsWiFiTransmitter.exe"
    if (Test-Path $exePath) {
        $exeSize = (Get-Item $exePath).Length / 1MB
        Write-Host "Executable: $exePath" -ForegroundColor Cyan
        Write-Host "Size: $([math]::Round($exeSize, 2)) MB`n" -ForegroundColor Cyan

        # Copy to root directory for convenience
        Copy-Item $exePath "..\TeamsWiFiTransmitter.exe" -Force
        Write-Host "[OK] Copied to: ..\TeamsWiFiTransmitter.exe`n" -ForegroundColor Green
    }
} else {
    Write-Host "`n[ERROR] Build failed!" -ForegroundColor Red
    exit 1
}
