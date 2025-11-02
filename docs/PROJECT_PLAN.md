# MS Teams Presence Notification Light - Complete Project Plan

## Project Overview

**Goal**: Create a PyPortal-based visual indicator that displays your Microsoft Teams presence status in real-time using colors and text.

**Components**:
1. Computer Service (Python) - Authenticates with MS Graph API and serves status data
2. PyPortal Device (CircuitPython) - Displays status with colors and text

**Estimated Timeline**: 2-3 days (depending on authentication setup)

---

## Phase 1: Authentication Setup (Day 1, Morning)

### Objective
Determine authentication method and obtain Azure AD credentials.

### Tasks

#### 1.1 Assess Azure AD Access
**Time**: 30 minutes
- [ ] Log in to https://portal.azure.com with work account
- [ ] Navigate to: Azure Active Directory → App registrations
- [ ] Check if "New registration" button is visible and accessible
- [ ] **Decision Point**:
  - If YES → Proceed with Option A (Self-Service)
  - If NO → Proceed with Option B (IT Request)

#### 1.2a Option A: Self-Service Azure AD App Registration
**Time**: 1-2 hours (if you have permissions)

**Steps**:
1. Go to Azure Portal → Azure Active Directory → App registrations → New registration
2. Fill in registration form:
   - Name: "PyPortal Teams Presence"
   - Supported account types: "Accounts in this organizational directory only"
   - Redirect URI: Leave blank
3. Click "Register"
4. Note the **Application (client) ID** and **Directory (tenant) ID**
5. Navigate to "Certificates & secrets" → "New client secret"
   - Description: "PyPortal Service"
   - Expires: 24 months
6. **IMPORTANT**: Copy the client secret value immediately (shown only once)
7. Navigate to "API permissions" → "Add a permission"
   - Select "Microsoft Graph" → "Delegated permissions"
   - Add: `User.Read`, `Presence.Read`
8. Click "Grant admin consent" (if available)
9. Store credentials in project:
   ```bash
   copy env.example .env
   notepad .env
   ```
10. Fill in `.env` with your values:
    ```
    AZURE_TENANT_ID=your-tenant-id-from-step-4
    AZURE_CLIENT_ID=your-client-id-from-step-4
    AZURE_CLIENT_SECRET=your-client-secret-from-step-6
    ```

#### 1.2b Option B: IT Department Request
**Time**: 1-5 days (depending on IT response time)

**Steps**:
1. Create IT ticket/email using this template:

```
Subject: Request for Azure AD App Registration - Teams Presence Indicator

Hi IT Team,

I would like to create a personal Teams presence indicator device using an
Adafruit PyPortal. This requires an Azure AD app registration with minimal
permissions.

Required Microsoft Graph API Permissions:
- User.Read (Delegated)
- Presence.Read (Delegated)

Application Details:
- Type: Confidential Client (Daemon/Service)
- Grant Type: Client Credentials
- Redirect URI: Not required
- Admin Consent: Not required (user-level permissions only)

Purpose:
Personal productivity tool to display my Teams status on an external device.
The application will only access my own Teams presence status.

Data Handling:
- No data storage (status displayed in real-time only)
- Runs on my local workstation only (localhost)
- No external network exposure

Security:
- Credentials stored locally in environment file
- Minimal API permissions (read-only, personal data only)
- Standard OAuth 2.0 authentication

Please provide:
1. Tenant ID
2. Client ID
3. Client Secret

Reference: This is similar to existing solutions like PresenceLight
(https://github.com/isaacrlevin/PresenceLight)

Thank you!
```

2. Wait for IT response
3. When credentials received, store in `.env` file as in Option A step 9-10

#### 1.3 Verify Credentials
**Time**: 15 minutes
- [ ] Ensure `.env` file exists and contains all three credentials
- [ ] Verify no extra spaces or quotes around values
- [ ] Confirm file is NOT committed to git (`git status` should not show `.env`)

---

## Phase 2: Computer Service Development (Day 1, Afternoon - Day 2, Morning)

### Objective
Build Python service that authenticates with MS Graph API and serves status via HTTP.

### Prerequisites
- Azure AD credentials configured in `.env`
- Python 3.8+ installed
- Internet connection

### Tasks

#### 2.1 Environment Setup
**Time**: 15 minutes
```bash
# Create and activate virtual environment
python -m venv venv
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Verify installation
pip list
```

#### 2.2 Implement Authentication Module
**Time**: 1 hour

Create `computer_service/auth.py`:
```python
"""
MS Graph Authentication using MSAL
"""
import os
import logging
from typing import Optional
from msal import ConfidentialClientApplication

logger = logging.getLogger(__name__)


class GraphAuthenticator:
    """Handles MS Graph API authentication"""

    def __init__(self):
        self.tenant_id = os.getenv('AZURE_TENANT_ID')
        self.client_id = os.getenv('AZURE_CLIENT_ID')
        self.client_secret = os.getenv('AZURE_CLIENT_SECRET')

        self.authority = f"https://login.microsoftonline.com/{self.tenant_id}"
        self.scope = ["https://graph.microsoft.com/.default"]

        self.app = ConfidentialClientApplication(
            client_id=self.client_id,
            client_credential=self.client_secret,
            authority=self.authority
        )

        self.token_cache = None

    def get_access_token(self) -> Optional[str]:
        """Acquire access token for MS Graph API"""
        try:
            # Try to get token from cache first
            result = self.app.acquire_token_silent(
                scopes=self.scope,
                account=None
            )

            if not result:
                # If no cached token, acquire new one
                result = self.app.acquire_token_for_client(
                    scopes=self.scope
                )

            if "access_token" in result:
                logger.info("Access token acquired successfully")
                return result["access_token"]
            else:
                error = result.get("error_description", "Unknown error")
                logger.error(f"Authentication failed: {error}")
                return None

        except Exception as e:
            logger.error(f"Token acquisition error: {e}", exc_info=True)
            return None
```

**Testing**:
```bash
# Test authentication
python -c "from computer_service.auth import GraphAuthenticator; auth = GraphAuthenticator(); print('Token:', auth.get_access_token()[:50] + '...')"
```

#### 2.3 Implement Presence Module
**Time**: 1 hour

Create `computer_service/presence.py`:
```python
"""
MS Teams Presence Status Retrieval
"""
import logging
import requests
from typing import Optional, Dict

logger = logging.getLogger(__name__)


class PresenceMonitor:
    """Monitors Teams presence status via MS Graph API"""

    GRAPH_ENDPOINT = "https://graph.microsoft.com/v1.0/me/presence"

    STATUS_COLORS = {
        'Available': '#00FF00',          # Green
        'Busy': '#FF0000',               # Red
        'Away': '#FFFF00',               # Yellow
        'BeRightBack': '#FFFF00',        # Yellow
        'DoNotDisturb': '#800080',       # Purple
        'InAMeeting': '#FF0000',         # Red
        'InACall': '#FF0000',            # Red
        'Offline': '#808080',            # Gray
        'OffWork': '#808080',            # Gray
        'OutOfOffice': '#808080',        # Gray
        'PresenceUnknown': '#FFFFFF',    # White
        'Unknown': '#FFFFFF'             # White
    }

    def __init__(self, authenticator):
        self.authenticator = authenticator
        self.current_status = None

    def fetch_presence(self) -> Optional[Dict]:
        """Fetch current Teams presence status"""
        try:
            token = self.authenticator.get_access_token()
            if not token:
                logger.error("No access token available")
                return None

            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }

            response = requests.get(
                self.GRAPH_ENDPOINT,
                headers=headers,
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                status = {
                    'availability': data.get('availability', 'Unknown'),
                    'activity': data.get('activity', 'Unknown'),
                    'color': self.STATUS_COLORS.get(
                        data.get('availability', 'Unknown'),
                        '#FFFFFF'
                    )
                }
                self.current_status = status
                logger.info(f"Presence updated: {status['availability']}")
                return status
            else:
                logger.error(f"Graph API error: {response.status_code} - {response.text}")
                return None

        except Exception as e:
            logger.error(f"Presence fetch error: {e}", exc_info=True)
            return None

    def get_current_status(self) -> Dict:
        """Get cached status or return unknown"""
        if self.current_status:
            return self.current_status
        return {
            'availability': 'Unknown',
            'activity': 'Unknown',
            'color': '#FFFFFF'
        }
```

**Testing**:
```bash
# Test presence fetching
python -c "from computer_service.auth import GraphAuthenticator; from computer_service.presence import PresenceMonitor; auth = GraphAuthenticator(); pm = PresenceMonitor(auth); print(pm.fetch_presence())"
```

#### 2.4 Implement HTTP Server
**Time**: 1 hour

Create `computer_service/server.py`:
```python
"""
Flask HTTP Server for PyPortal Communication
"""
import logging
from flask import Flask, jsonify
from flask_cors import CORS

logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for PyPortal requests

# Will be set by main.py
presence_monitor = None


@app.route('/status', methods=['GET'])
def get_status():
    """Return current Teams presence status"""
    try:
        if presence_monitor:
            status = presence_monitor.get_current_status()
            logger.debug(f"Status requested: {status}")
            return jsonify(status), 200
        else:
            return jsonify({'error': 'Service not initialized'}), 503
    except Exception as e:
        logger.error(f"Status endpoint error: {e}", exc_info=True)
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'}), 200


def run_server(host='0.0.0.0', port=8080):
    """Start Flask server"""
    logger.info(f"Starting HTTP server on {host}:{port}")
    app.run(host=host, port=port, debug=False, threaded=True)
```

#### 2.5 Update Main Service
**Time**: 30 minutes

Update `computer_service/main.py`:
```python
"""
MS Teams Presence Notification Light - Main Service
"""
import os
import sys
import time
import logging
import threading
from dotenv import load_dotenv

from .auth import GraphAuthenticator
from .presence import PresenceMonitor
from . import server

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class TeamsPresenceService:
    """Main service for MS Teams Presence monitoring"""

    def __init__(self):
        """Initialize the service"""
        load_dotenv()

        self.server_host = os.getenv('SERVER_HOST', '0.0.0.0')
        self.server_port = int(os.getenv('SERVER_PORT', 8080))
        self.polling_interval = int(os.getenv('POLLING_INTERVAL', 30))

        # Initialize components
        self.authenticator = GraphAuthenticator()
        self.presence_monitor = PresenceMonitor(self.authenticator)

        # Make presence monitor available to server
        server.presence_monitor = self.presence_monitor

        self.running = False

    def start_polling(self):
        """Start background thread for presence polling"""
        def poll_loop():
            logger.info("Presence polling started")
            while self.running:
                try:
                    self.presence_monitor.fetch_presence()
                except Exception as e:
                    logger.error(f"Polling error: {e}", exc_info=True)
                time.sleep(self.polling_interval)
            logger.info("Presence polling stopped")

        thread = threading.Thread(target=poll_loop, daemon=True)
        thread.start()
        return thread

    def run(self):
        """Run the service"""
        logger.info("MS Teams Presence Service starting...")
        logger.info(f"Server: {self.server_host}:{self.server_port}")
        logger.info(f"Polling interval: {self.polling_interval}s")

        # Start presence polling
        self.running = True
        poll_thread = self.start_polling()

        # Fetch initial status
        time.sleep(2)  # Give authentication time to complete

        # Start HTTP server (blocks)
        server.run_server(
            host=self.server_host,
            port=self.server_port
        )


def main():
    """Main entry point"""
    try:
        service = TeamsPresenceService()
        service.run()
    except KeyboardInterrupt:
        logger.info("Service stopped by user")
    except Exception as e:
        logger.error(f"Service error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
```

#### 2.6 Test Computer Service
**Time**: 30 minutes

```bash
# Run the service
python computer_service/main.py

# In another terminal, test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/status

# Or with PowerShell
Invoke-WebRequest -Uri http://localhost:8080/status | ConvertFrom-Json
```

**Expected Output**:
```json
{
  "availability": "Available",
  "activity": "Available",
  "color": "#00FF00"
}
```

---

## Phase 3: PyPortal Setup (Day 2, Afternoon)

### Objective
Install CircuitPython on PyPortal and prepare the device.

### Prerequisites
- Adafruit PyPortal device
- USB-C cable
- Windows computer

### Tasks

#### 3.1 Install CircuitPython
**Time**: 30 minutes

1. **Download CircuitPython**:
   - Visit: https://circuitpython.org/board/pyportal/
   - Download latest stable CircuitPython UF2 file

2. **Enter Bootloader Mode**:
   - Connect PyPortal to computer via USB-C
   - Double-tap the RESET button quickly
   - PyPortal screen turns green, and PORTALBOOT drive appears

3. **Install CircuitPython**:
   - Copy downloaded UF2 file to PORTALBOOT drive
   - Wait for automatic restart
   - CIRCUITPY drive appears

4. **Verify Installation**:
   - Open CIRCUITPY drive
   - Check `boot_out.txt` for CircuitPython version

#### 3.2 Install Required Libraries
**Time**: 30 minutes

1. **Download CircuitPython Bundle**:
   - Visit: https://circuitpython.org/libraries
   - Download bundle matching your CircuitPython version
   - Extract the zip file

2. **Create lib Folder**:
   ```bash
   # If lib doesn't exist on CIRCUITPY drive
   mkdir E:\lib
   ```

3. **Copy Required Libraries**:
   ```bash
   # Copy these folders/files to E:\lib\
   # (Replace E: with your CIRCUITPY drive letter)

   copy circuitpython-bundle\lib\adafruit_display_text E:\lib\
   copy circuitpython-bundle\lib\adafruit_bitmap_font E:\lib\
   copy circuitpython-bundle\lib\adafruit_requests.mpy E:\lib\
   copy circuitpython-bundle\lib\adafruit_esp32spi E:\lib\
   copy circuitpython-bundle\lib\adafruit_portalbase E:\lib\
   ```

#### 3.3 Configure WiFi
**Time**: 15 minutes

Create `pyportal/secrets.py`:
```python
secrets = {
    "ssid": "Your-WiFi-Name",
    "password": "Your-WiFi-Password",
    "server_url": "http://192.168.1.100:8080/status"  # Replace with your computer's IP
}
```

**Find Your Computer's IP**:
```bash
ipconfig
# Look for "IPv4 Address" under your WiFi adapter
# Example: 192.168.1.100
```

---

## Phase 4: PyPortal Code Development (Day 2, Evening)

### Objective
Implement CircuitPython code for PyPortal.

### Tasks

#### 4.1 Create Main PyPortal Code
**Time**: 2 hours

Create `pyportal/code.py`:
```python
"""
MS Teams Presence PyPortal Display
"""
import time
import board
import busio
from digitalio import DigitalInOut
import displayio
import terminalio
from adafruit_display_text import label
import adafruit_requests as requests
import adafruit_esp32spi.adafruit_esp32spi_socket as socket
from adafruit_esp32spi import adafruit_esp32spi

# Import WiFi credentials
try:
    from secrets import secrets
except ImportError:
    print("WiFi secrets not found!")
    raise

# Setup
print("Teams Presence Light Starting...")

# ESP32 SPI pins
esp32_cs = DigitalInOut(board.ESP_CS)
esp32_ready = DigitalInOut(board.ESP_BUSY)
esp32_reset = DigitalInOut(board.ESP_RESET)

spi = busio.SPI(board.SCK, board.MOSI, board.MISO)
esp = adafruit_esp32spi.ESP_SPIcontrol(spi, esp32_cs, esp32_ready, esp32_reset)

# Connect to WiFi
print(f"Connecting to {secrets['ssid']}...")
while not esp.is_connected:
    try:
        esp.connect_AP(secrets["ssid"], secrets["password"])
    except RuntimeError as e:
        print(f"Connection failed: {e}")
        time.sleep(5)
        continue

print("Connected!")
print(f"IP: {esp.pretty_ip(esp.ip_address)}")

# Setup HTTP
socket.set_interface(esp)
requests_session = requests.Session(socket)

# Setup display
display = board.DISPLAY
group = displayio.Group()

# Status colors
COLORS = {
    '#00FF00': 0x00FF00,  # Green - Available
    '#FF0000': 0xFF0000,  # Red - Busy
    '#FFFF00': 0xFFFF00,  # Yellow - Away
    '#800080': 0x800080,  # Purple - DND
    '#808080': 0x808080,  # Gray - Offline
    '#FFFFFF': 0xFFFFFF,  # White - Unknown
}

# Create background color rectangle
color_bitmap = displayio.Bitmap(320, 240, 1)
color_palette = displayio.Palette(1)
color_palette[0] = 0xFFFFFF  # Default white
bg_sprite = displayio.TileGrid(
    color_bitmap,
    pixel_shader=color_palette,
    x=0, y=0
)
group.append(bg_sprite)

# Create status text
text_area = label.Label(
    terminalio.FONT,
    text="Starting...",
    color=0x000000,
    scale=3,
    x=20, y=120
)
group.append(text_area)

display.show(group)

# Main loop
UPDATE_INTERVAL = 30  # seconds
last_update = 0

def update_status():
    """Fetch and display Teams status"""
    try:
        response = requests_session.get(secrets["server_url"], timeout=10)
        data = response.json()
        response.close()

        availability = data.get("availability", "Unknown")
        color_hex = data.get("color", "#FFFFFF")

        # Update background color
        color_value = COLORS.get(color_hex, 0xFFFFFF)
        color_palette[0] = color_value

        # Update text
        text_area.text = availability

        # Adjust text color for visibility
        if color_hex in ['#FFFF00', '#FFFFFF']:  # Yellow or White
            text_area.color = 0x000000  # Black text
        else:
            text_area.color = 0xFFFFFF  # White text

        print(f"Status: {availability} ({color_hex})")
        return True

    except Exception as e:
        print(f"Update error: {e}")
        text_area.text = "Error"
        return False

print("Starting status monitoring...")

while True:
    current_time = time.monotonic()

    if current_time - last_update >= UPDATE_INTERVAL:
        if update_status():
            last_update = current_time

    time.sleep(1)
```

#### 4.2 Deploy to PyPortal
**Time**: 15 minutes

```bash
# Copy files to PyPortal
copy pyportal\code.py E:\code.py
copy pyportal\secrets.py E:\secrets.py

# PyPortal will automatically restart and run code.py
```

#### 4.3 Monitor and Test
**Time**: 30 minutes

1. **Connect Serial Monitor**:
   - Install mu-editor: `pip install mu-editor`
   - Run mu-editor
   - Click "Serial" button to view output

2. **Verify Behavior**:
   - Check WiFi connection messages
   - Confirm HTTP requests succeeding
   - Watch status updates every 30 seconds
   - Verify display showing correct status and colors

3. **Test Status Changes**:
   - Change your Teams status
   - Wait 30-60 seconds for update
   - Confirm PyPortal display updates

---

## Phase 5: Testing & Refinement (Day 3)

### Objective
Comprehensive testing and bug fixes.

### Tasks

#### 5.1 Computer Service Tests
**Time**: 1 hour

Create `tests/test_presence.py`:
```python
import pytest
from computer_service.presence import PresenceMonitor

def test_status_colors():
    """Test status color mappings"""
    assert PresenceMonitor.STATUS_COLORS['Available'] == '#00FF00'
    assert PresenceMonitor.STATUS_COLORS['Busy'] == '#FF0000'
    assert PresenceMonitor.STATUS_COLORS['Away'] == '#FFFF00'
```

Run tests:
```bash
pytest tests/
```

#### 5.2 Integration Testing
**Time**: 2 hours

- [ ] Test with all Teams statuses (Available, Busy, Away, DND, etc.)
- [ ] Test error handling (disconnect WiFi, stop service, etc.)
- [ ] Test recovery from errors
- [ ] Test long-term stability (leave running for hours)
- [ ] Test token refresh (leave running across token expiry)

#### 5.3 Performance Optimization
**Time**: 1 hour

- [ ] Monitor CPU usage (should be <5%)
- [ ] Check memory usage (should be <100MB)
- [ ] Verify no memory leaks
- [ ] Confirm PyPortal response time <2 seconds

#### 5.4 Documentation
**Time**: 1 hour

- [ ] Complete setup guides
- [ ] Add troubleshooting section
- [ ] Document common issues
- [ ] Create user guide

---

## Phase 6: Deployment (Day 3)

### Objective
Deploy for permanent use.

### Tasks

#### 6.1 Configure Auto-Start (Computer Service)
**Time**: 30 minutes

**Option A: Task Scheduler**
1. Open Task Scheduler
2. Create Basic Task:
   - Name: "Teams Presence Service"
   - Trigger: "At log on"
   - Action: "Start a program"
   - Program: `C:\Users\YourName\AppData\Local\Programs\Python\Python311\python.exe`
   - Arguments: `D:\Repos\MSTeams-Presence-Notify\computer_service\main.py`
   - Start in: `D:\Repos\MSTeams-Presence-Notify`
3. Configure to run only when user is logged in

**Option B: Startup Folder**
Create `start_presence_service.bat`:
```batch
@echo off
cd /d D:\Repos\MSTeams-Presence-Notify
call venv\Scripts\activate
python computer_service\main.py
```
Place in: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`

#### 6.2 Configure Firewall
**Time**: 15 minutes

```powershell
# Run PowerShell as Administrator
netsh advfirewall firewall add rule name="Teams Presence Service" dir=in action=allow protocol=TCP localport=8080
```

#### 6.3 Position PyPortal
**Time**: 15 minutes

- [ ] Place PyPortal where visible (desk, monitor side, etc.)
- [ ] Connect USB power (can use monitor USB port or wall adapter)
- [ ] Verify WiFi coverage
- [ ] Test visibility in various lighting conditions

---

## Troubleshooting Guide

### Computer Service Issues

#### Authentication Errors
**Symptom**: "Authentication failed" in logs
**Solutions**:
1. Verify `.env` credentials are correct
2. Check if Azure AD app has correct permissions
3. Verify tenant ID is correct
4. Try regenerating client secret

#### Port Already in Use
**Symptom**: "Address already in use" error
**Solutions**:
```powershell
# Find process using port 8080
netstat -ano | findstr :8080

# Kill process (replace PID with actual process ID)
taskkill /F /PID <PID>
```

#### Graph API Errors
**Symptom**: 401/403 responses from Graph API
**Solutions**:
1. Check token hasn't expired (should auto-refresh)
2. Verify API permissions granted in Azure AD
3. Check if admin consent required
4. Test with Graph Explorer: https://developer.microsoft.com/graph/graph-explorer

### PyPortal Issues

#### Won't Connect to WiFi
**Solutions**:
1. Verify SSID and password in `secrets.py`
2. Check WiFi is 2.4GHz (PyPortal doesn't support 5GHz)
3. Try WiFi network without special characters in name
4. Check if MAC filtering enabled on router

#### Can't Reach Computer Service
**Solutions**:
1. Verify computer IP address hasn't changed
2. Check firewall allows port 8080
3. Ensure computer and PyPortal on same network
4. Test with `ping` from another device

#### Display Issues
**Solutions**:
1. Check PyPortal has enough power (try wall adapter)
2. Verify CircuitPython version compatibility
3. Check all libraries copied correctly
4. Try soft reset (press RESET button once)

#### Memory Errors
**Solutions**:
1. Remove unnecessary libraries from `lib/`
2. Simplify display code
3. Update CircuitPython to latest version
4. Hard reset PyPortal and reinstall

---

## Success Criteria

### Computer Service
✅ Service starts without errors
✅ Authenticates successfully with Azure AD
✅ Fetches Teams presence status
✅ HTTP server responds on port 8080
✅ Status updates every 30 seconds
✅ Runs stable for 24+ hours

### PyPortal
✅ Connects to WiFi automatically
✅ Displays status with correct colors
✅ Updates status every 30 seconds
✅ Text is readable
✅ Recovers from network errors
✅ Runs stable for 24+ hours

### Integration
✅ PyPortal shows real Teams status
✅ Updates within 60 seconds of status change
✅ System recovers from computer sleep/restart
✅ No manual intervention required

---

## Maintenance

### Daily
- Verify service is running
- Check PyPortal displaying correctly

### Weekly
- Review logs for errors
- Check token refresh working

### Monthly
- Update Python dependencies: `pip install --upgrade -r requirements.txt`
- Check for CircuitPython updates
- Review Azure AD app secret expiry date

### When Issues Arise
1. Check computer service logs
2. Check PyPortal serial output
3. Verify network connectivity
4. Review recent Windows/Teams updates
5. Check Azure AD app still has permissions

---

## Next Steps After Completion

### Optional Enhancements
- Add buttons for manual refresh
- Implement configurable colors
- Add audio alerts for status changes
- Support multiple users (if permitted)
- Add touchscreen controls
- Display additional info (meeting duration, next meeting)
- Log status history for analytics

### Sharing Your Success
- Take photos of your setup
- Document any improvements you made
- Share on Adafruit forums or Reddit
- Contribute improvements to this project

---

**Ready to Begin?** Start with Phase 1, Task 1.1 - Assess Azure AD Access!
