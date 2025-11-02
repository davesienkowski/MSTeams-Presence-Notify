# Alternative Methods for MS Teams Presence Detection

Based on research conducted in January 2025, here are all viable methods for accessing MS Teams presence status, including alternatives that don't require full MS Graph API authentication.

---

## Summary Table

| Method | Auth Required | Complexity | Reliability | New Teams Compatible | Recommendation |
|--------|--------------|------------|-------------|---------------------|----------------|
| **Option A: MS Graph API (Self-Service)** | Azure AD App | Medium | ⭐⭐⭐⭐⭐ | ✅ Yes | Best for personal control |
| **Option B: MS Graph API (IT Request)** | Azure AD App (via IT) | Low | ⭐⭐⭐⭐⭐ | ✅ Yes | **Recommended for work** |
| **Option C: PresenceLight Bridge** | Via PresenceLight | Low | ⭐⭐⭐⭐ | ✅ Yes | Good fallback |
| **Option D: PowerShell Log Monitoring** | None | Medium | ⭐⭐⭐ | ⚠️ Partial | Works but less reliable |
| **Option E: UI Automation** | None | High | ⭐⭐ | ⚠️ Fragile | Windows-only, fragile |
| **Option F: Azure CLI Token** | Azure CLI login | Medium | ⭐⭐⭐⭐ | ✅ Yes | Simplified auth |
| **Option G: Command-Line Args** | None | Low | ⭐⭐ | ⚠️ Undocumented | May break anytime |

---

## Detailed Breakdown

### Option A: MS Graph API (Self-Service)
**Already documented** in [PROJECT_PLAN.md](PROJECT_PLAN.md) Phase 1, Task 1.2a

**Summary**: Register your own Azure AD app with Presence.Read permissions

**Pros**:
- ✅ Most reliable and official method
- ✅ Full control over the application
- ✅ Direct MS Graph API access
- ✅ Works with New Teams

**Cons**:
- ❌ Requires Azure AD app registration permissions
- ❌ May not be available in corporate environments

---

### Option B: MS Graph API (IT Request)
**Already documented** in [PROJECT_PLAN.md](PROJECT_PLAN.md) Phase 1, Task 1.2b

**Summary**: Request IT department to create Azure AD app registration

**Pros**:
- ✅ Most appropriate for work environment
- ✅ Officially sanctioned by IT
- ✅ Same reliability as Option A
- ✅ Works with New Teams

**Cons**:
- ❌ Requires IT ticket/request
- ❌ May take time to provision

**Recommended Approach**: This remains the best option for work computers.

---

### Option C: PresenceLight Bridge
**Already documented** in [authentication_strategy.md](../memory/authentication_strategy.md)

**Summary**: Use existing PresenceLight tool as intermediary

**Pros**:
- ✅ No Azure AD registration needed
- ✅ Well-tested open-source solution
- ✅ Works with New Teams
- ✅ Can control other smart lights too

**Cons**:
- ❌ Additional dependency
- ❌ More complex architecture

---

### Option D: PowerShell Log Monitoring ⭐ NEW
**Description**: Monitor Teams log files locally without API authentication

**How It Works**:
1. PowerShell script monitors Teams log file
2. Parses status changes from log entries
3. Serves status via HTTP endpoint
4. PyPortal connects to the endpoint

**Implementation**:

#### Step 1: Use EBOOZ TeamsStatus Script
- **GitHub**: https://github.com/EBOOZ/TeamsStatus
- **Method**: Monitors `MSTeams\Logs\` directory
- **Detection**: Parses log patterns like `SetBadge Setting badge:` and `SetTaskbarIconOverlay`

#### Step 2: Adapt for PyPortal
We can modify the PowerShell script to serve status over HTTP instead of Home Assistant API.

**Modified PowerShell Script** (`TeamsStatusServer.ps1`):

```powershell
# Teams Status HTTP Server for PyPortal
# Based on EBOOZ/TeamsStatus

$Port = 8080
$LocalUsername = $env:USERNAME

# Log file location (New Teams)
$TeamsLogPath = "C:\Users\$LocalUsername\AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs\"

# Current status cache
$CurrentStatus = @{
    availability = "Unknown"
    activity = "Unknown"
    color = "#FFFFFF"
}

# Color mapping
$ColorMap = @{
    "Available" = "#00FF00"
    "Busy" = "#FF0000"
    "Away" = "#FFFF00"
    "DoNotDisturb" = "#800080"
    "Focusing" = "#800080"
    "Presenting" = "#FF0000"
    "InAMeeting" = "#FF0000"
    "Offline" = "#808080"
}

# Simple HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "Teams Status Server running on http://localhost:$Port/"
Write-Host "Press Ctrl+C to stop"

# Background job for status monitoring
$MonitorJob = Start-Job -ScriptBlock {
    param($LogPath, $StatusRef)

    while ($true) {
        try {
            # Check if Teams is running
            $TeamsProcess = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue

            if ($TeamsProcess) {
                # Get latest log file
                $LogFiles = Get-ChildItem -Path $LogPath -Filter "*.log" | Sort-Object LastWriteTime -Descending

                if ($LogFiles) {
                    $LatestLog = $LogFiles[0].FullName
                    $LogContent = Get-Content -Path $LatestLog -Tail 1000 | Out-String

                    # Parse availability status
                    if ($LogContent -match "SetBadge Setting badge:.*available") {
                        $StatusRef.availability = "Available"
                    }
                    elseif ($LogContent -match "SetBadge Setting badge:.*busy|inameeting") {
                        $StatusRef.availability = "Busy"
                    }
                    elseif ($LogContent -match "SetBadge Setting badge:.*away") {
                        $StatusRef.availability = "Away"
                    }
                    elseif ($LogContent -match "SetBadge Setting badge:.*doNotDisturb|Do not disturb") {
                        $StatusRef.availability = "DoNotDisturb"
                    }
                    elseif ($LogContent -match "SetBadge Setting badge:.*offline") {
                        $StatusRef.availability = "Offline"
                    }

                    # Parse activity (in call or not)
                    if ($LogContent -match "NotifyCallActive|NotifyCallAccepted") {
                        $StatusRef.activity = "InACall"
                    }
                    elseif ($LogContent -match "NotifyCallEnded") {
                        $StatusRef.activity = "Available"
                    }
                }
            }
            else {
                $StatusRef.availability = "Offline"
                $StatusRef.activity = "Offline"
            }
        }
        catch {
            Write-Host "Error monitoring logs: $_"
        }

        Start-Sleep -Seconds 5
    }
} -ArgumentList $TeamsLogPath, $CurrentStatus

# HTTP request handler
while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        if ($request.Url.AbsolutePath -eq "/status") {
            # Get current status
            $availability = $CurrentStatus.availability
            $color = $ColorMap[$availability]
            if (-not $color) { $color = "#FFFFFF" }

            # Build JSON response
            $json = @{
                availability = $availability
                activity = $CurrentStatus.activity
                color = $color
            } | ConvertTo-Json

            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentLength64 = $buffer.Length
            $response.ContentType = "application/json"
            $response.AddHeader("Access-Control-Allow-Origin", "*")
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()

            Write-Host "Served status: $availability"
        }
        else {
            $response.StatusCode = 404
            $response.Close()
        }
    }
    catch {
        Write-Host "Request error: $_"
    }
}

# Cleanup
Stop-Job $MonitorJob
Remove-Job $MonitorJob
$listener.Stop()
```

**Usage**:
```powershell
# Run the server
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1

# Test with curl
curl http://localhost:8080/status
```

**Expected Output**:
```json
{
  "availability": "Available",
  "activity": "Available",
  "color": "#00FF00"
}
```

**Pros**:
- ✅ No Azure AD authentication required
- ✅ Works locally on your computer
- ✅ No IT permissions needed
- ✅ Fast response time (local)
- ✅ No external dependencies

**Cons**:
- ❌ New Teams logs less reliable than Classic Teams
- ❌ Status detection may be delayed (5-10 seconds)
- ❌ Requires PowerShell to run continuously
- ❌ May break if Microsoft changes log format
- ❌ Classic Teams ends support July 1, 2025 (already on New Teams)

**Reliability**: ⭐⭐⭐ Works but less reliable than Graph API

**New Teams Compatibility**: ⚠️ Partial - works but with limitations

---

### Option E: UI Automation (Windows)
**Description**: Read Teams status from UI elements using Windows automation

**How It Works**:
- Uses `UIAutomationClient` class (Windows-only)
- Searches for UI element: "Your profile picture with status displayed as"
- Extracts status from element name

**Implementation** (C#/.NET required):
```csharp
using System.Windows.Automation;

AutomationElement teamsWindow = AutomationElement.RootElement;
// Find Teams window and profile button
// Extract status from element name
```

**Pros**:
- ✅ No authentication required
- ✅ No log file parsing needed
- ✅ Works with minimized Teams

**Cons**:
- ❌ Windows-only
- ❌ Requires .NET/C# or Python with pywinauto
- ❌ Fragile (breaks if UI changes)
- ❌ High complexity
- ❌ May not work with New Teams UI changes

**Reliability**: ⭐⭐ Fragile and Windows-specific

**Recommendation**: Not recommended unless other options fail

---

### Option F: Azure CLI Token Method
**Description**: Use Azure CLI to get access token, avoiding full app registration

**How It Works**:
1. Install Azure CLI
2. Login: `az login`
3. Get token: `az account get-access-token --resource https://presence.teams.microsoft.com`
4. Use token to call presence API directly

**Implementation**:
```python
import subprocess
import json
import requests

# Get token via Azure CLI
result = subprocess.run(
    ['az', 'account', 'get-access-token', '--resource', 'https://presence.teams.microsoft.com'],
    capture_output=True,
    text=True
)
token_data = json.loads(result.stdout)
token = token_data['accessToken']

# Call Teams presence API directly
headers = {'Authorization': f'Bearer {token}'}
response = requests.get(
    'https://presence.teams.microsoft.com/v1/me/forceavailability/',
    headers=headers
)
```

**Pros**:
- ✅ Simpler than full Graph API setup
- ✅ No Azure AD app registration
- ✅ Official Microsoft authentication

**Cons**:
- ❌ Requires Azure CLI installation
- ❌ Token expires after ~1 hour
- ❌ Need to re-authenticate periodically
- ❌ Still requires Azure AD credentials

**Reliability**: ⭐⭐⭐⭐ Good but tokens expire

**Recommendation**: Good middle ground if you have Azure CLI

---

### Option G: Command-Line Arguments (Undocumented)
**Description**: Use undocumented Teams command-line switches

**Available Commands**:
```bash
ms-teams.exe --set-presence-to-available
ms-teams.exe --set-presence-to-busy
ms-teams.exe --set-presence-to-dnd
ms-teams.exe --set-presence-to-away
ms-teams.exe --set-presence-to-offline
ms-teams.exe --reset-presence
```

**How to Use**:
These can SET status but cannot READ status. Not useful for our use case.

**Pros**:
- ✅ No authentication

**Cons**:
- ❌ Can only SET status, not READ it
- ❌ Undocumented (may be removed)
- ❌ Not useful for PyPortal display

**Recommendation**: ❌ Not applicable for our project

---

## Final Recommendations

### For Work Computer with Admin Access:

**Primary Recommendation**: **Option B (IT Request)**
- Most appropriate for corporate environment
- Reliable and officially supported
- Use provided email template in PROJECT_PLAN.md

**Quick Alternative**: **Option D (PowerShell Log Monitoring)**
- No permissions needed
- Implement now while waiting for IT
- Can switch to Option B later for reliability

**Fallback**: **Option C (PresenceLight Bridge)**
- If IT denies request and logs don't work well

### Decision Tree:

```
Start
  ├─ Can you request IT to create Azure AD app?
  │   └─ YES → Option B (IT Request) ✅ BEST
  │
  ├─ Can you create Azure AD app yourself?
  │   └─ YES → Option A (Self-Service) ✅ GOOD
  │
  ├─ Want to try without authentication first?
  │   └─ YES → Option D (PowerShell Logs) ⚠️ WORKS
  │
  └─ All above failed?
      └─ YES → Option C (PresenceLight) ✅ RELIABLE FALLBACK
```

---

## Implementation Support

I can help you implement **any of these options**:

1. **Option B (IT Request)** - Draft email, configure credentials
2. **Option D (PowerShell)** - Set up PowerShell server, test with PyPortal
3. **Option C (PresenceLight)** - Install and configure bridge
4. **Option F (Azure CLI)** - Set up CLI authentication flow

**Which option would you like to pursue?**
