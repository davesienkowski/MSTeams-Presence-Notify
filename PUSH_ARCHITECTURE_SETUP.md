# Push Architecture Setup Guide

**For networks where Work PC can reach Home, but Home cannot reach Work PC**

## Architecture Overview

```
┌─────────────────────────┐          ┌──────────────────────────┐
│   WORK PC (Client)      │          │   HOME - Raspberry Pi    │
│   Corporate Network     │          │   (Server)               │
│                         │          │                          │
│  MS Teams               │   HTTP   │  teams_status_server.py  │
│       ↓                 │   POST   │         ↓                │
│  Log Monitor            │  ─────►  │    HTTP Server           │
│       ↓                 │          │         ↓                │
│  TeamsPushClient.ps1    │          │    Unicorn HAT           │
│  (Pushes every 5s)      │          │    8x8 LED Matrix 🌈     │
│                         │          │                          │
└─────────────────────────┘          └──────────────────────────┘
```

**Key Difference**: Work PC actively **pushes** status to Raspberry Pi (instead of Pi pulling from PC).

---

## Prerequisites

### On Raspberry Pi (Home Network):
- Raspberry Pi 3 Model B+ with Raspberry Pi OS
- Pimoroni Unicorn HAT (8x8 LED matrix)
- Python 3 with packages: `unicornhat`, `requests` (requests not needed for server, but useful)
- **Static IP address or DDNS hostname** (so work PC can reach it)

### On Work PC (Corporate Network):
- Windows PC with Microsoft Teams
- PowerShell 5.1+
- Ability to make **outbound** HTTP connections to home network

---

## Step-by-Step Setup

### Part 1: Raspberry Pi Setup (Home)

#### 1. Find Your Raspberry Pi's IP Address

```bash
# On Raspberry Pi:
hostname -I
```

Note this IP address (e.g., `192.168.1.150`)

#### 2. Set Up Port Forwarding (Optional but Recommended)

**If your Work PC is on a completely different network:**

On your home router, forward port 8080 to your Raspberry Pi:
- **External Port**: 8080
- **Internal IP**: Your Raspberry Pi's IP (e.g., 192.168.1.150)
- **Internal Port**: 8080
- **Protocol**: TCP

You'll also need your **public home IP** (find at https://whatismyipaddress.com)

#### 3. Install Dependencies

```bash
# Install Unicorn HAT library
sudo pip3 install unicornhat==2.2.3 --break-system-packages

# Or use Pimoroni installer:
curl -sS https://get.pimoroni.com/unicornhat | bash
```

#### 4. Download Server Script

```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
# File should already be there from git clone
```

#### 5. Run Server

```bash
sudo python3 teams_status_server.py
```

You should see:
```
==============================================================
MS Teams Presence Server - Raspberry Pi Unicorn HAT
==============================================================
Server listening on port: 8080
Animation mode: pulse
Brightness: 50%

Work PC should POST status updates to:
  http://<raspberry-pi-ip>:8080/status

Press Ctrl+C to exit

Server started successfully on port 8080
Waiting for status updates from work PC...
```

---

### Part 2: Work PC Setup (Corporate Network)

#### 1. Edit Configuration

Open `TeamsPushClient.ps1` and edit line 6:

```powershell
$RaspberryPiIP = "192.168.1.150"  # Change to your Raspberry Pi's IP
```

**Options:**
- **Same network**: Use local IP (e.g., `192.168.1.150`)
- **Different network**: Use public IP and port forwarding (e.g., `1.2.3.4`)
- **Dynamic DNS**: Use hostname (e.g., `myhome.dyndns.org`)

#### 2. Test Connection

```powershell
# Test if you can reach Raspberry Pi
Invoke-RestMethod -Uri "http://192.168.1.150:8080/" -Method GET
```

You should see HTML response confirming the server is running.

#### 3. Run Push Client

```powershell
cd D:\Repos\MSTeams-Presence-Notify\powershell_service
powershell -ExecutionPolicy Bypass -File TeamsPushClient.ps1
```

You should see:
```
======================================================================
 MS Teams Status Push Client
======================================================================

[2025-01-02 10:30:00] [INFO] Raspberry Pi IP: 192.168.1.150
[2025-01-02 10:30:00] [INFO] Port: 8080
[2025-01-02 10:30:00] [INFO] Poll interval: 5 seconds

[2025-01-02 10:30:00] [INFO] Testing connection to Raspberry Pi...
[2025-01-02 10:30:00] [SUCCESS] Successfully connected to Raspberry Pi at 192.168.1.150

[2025-01-02 10:30:00] [INFO] Starting Teams status monitoring...
[2025-01-02 10:30:00] [INFO] Press Ctrl+C to stop

[2025-01-02 10:30:05] [SUCCESS] Status changed: Unknown → Available
```

#### 4. Verify on Raspberry Pi

Your Unicorn HAT should light up with your Teams status color! 🌈

---

## Troubleshooting

### Cannot Reach Raspberry Pi from Work PC

**Error**: `Failed to send update to Raspberry Pi`

**Solutions**:

1. **Check IP Address:**
   ```bash
   # On Raspberry Pi:
   hostname -I
   ```

2. **Verify Server is Running:**
   ```bash
   # On Raspberry Pi:
   sudo python3 teams_status_server.py
   ```

3. **Test from Work PC:**
   ```powershell
   # On Work PC:
   Test-NetConnection -ComputerName 192.168.1.150 -Port 8080
   ```

4. **Check Firewall (Raspberry Pi):**
   ```bash
   # Allow port 8080 on Raspberry Pi
   sudo ufw allow 8080/tcp
   ```

5. **Port Forwarding Issues:**
   - Verify router port forwarding is configured correctly
   - Test with public IP instead of local IP
   - Check if corporate firewall blocks outbound connections to home

---

### Teams Status Not Updating

**Check Teams Logs:**

```powershell
# On Work PC, verify logs exist:
Test-Path "$env:APPDATA\Microsoft\Teams\logs.txt"
```

**Increase Verbosity:**

Edit `TeamsPushClient.ps1` and add more logging around line 95.

---

### Raspberry Pi Not Displaying Status

**Verify Unicorn HAT:**

```bash
# Test HAT directly:
sudo python3 -c "import unicornhat; unicornhat.set_pixel(0,0,255,0,0); unicornhat.show()"
```

Top-left LED should turn red.

**Check Logs:**

Look at Raspberry Pi terminal for received status updates.

---

## Advanced Configuration

### Auto-Start Server on Raspberry Pi Boot

Create systemd service:

```bash
sudo nano /etc/systemd/system/teams-status-server.service
```

Add:
```ini
[Unit]
Description=MS Teams Status Server for Unicorn HAT
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn
ExecStart=/usr/bin/python3 /home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn/teams_status_server.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable teams-status-server.service
sudo systemctl start teams-status-server.service
```

### Auto-Start Client on Work PC Login

Create scheduled task:

1. Open **Task Scheduler**
2. **Create Task** (not Basic Task)
3. **General** tab:
   - Name: `Teams Status Push Client`
   - Run whether user is logged on or not: **No** (unchecked)
   - Run with highest privileges: **No** (unchecked)
4. **Triggers** tab:
   - New trigger: **At log on** (of specific user)
5. **Actions** tab:
   - Action: **Start a program**
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\Repos\MSTeams-Presence-Notify\powershell_service\TeamsPushClient.ps1"`
6. **Conditions** tab:
   - Uncheck "Start only if computer is on AC power"
7. **Settings** tab:
   - Allow task to be run on demand: **Yes**
   - If task is already running: **Do not start a new instance**

---

## Customization

### Change Animation Mode (Raspberry Pi)

Edit `teams_status_server.py` line 21:

```python
ANIMATION_MODE = "ripple"  # Options: solid, pulse, gradient, ripple, spinner
```

### Change Brightness

Edit line 20:
```python
BRIGHTNESS = 0.3  # 30% brightness (easier on eyes)
```

### Change Update Frequency (Work PC)

Edit `TeamsPushClient.ps1` line 9:

```powershell
[int]$PollInterval = 10  # Check every 10 seconds instead of 5
```

---

## Security Considerations

### Exposing Raspberry Pi to Internet

If you use port forwarding to make Pi accessible from work:

1. **Use Strong WiFi Password**: Ensure your home network is secure
2. **Firewall Rules**: Only allow port 8080, block all other ports
3. **Monitor Logs**: Check for suspicious access attempts
4. **Consider VPN**: Set up VPN connection to home instead of port forwarding

### Alternative: VPN Approach

Instead of port forwarding, set up VPN:

1. Install **WireGuard** or **OpenVPN** on Raspberry Pi
2. Connect Work PC to home network via VPN
3. Use local IP address (no port forwarding needed)
4. More secure, encrypted connection

---

## Comparison: Push vs. Pull Architecture

| Aspect | **Push (This Guide)** | Pull (Original) |
|--------|-----------------------|-----------------|
| **Work PC** | Pushes status OUT | Hosts HTTP server |
| **Raspberry Pi** | Receives status (server) | Pulls status (client) |
| **Best For** | Work PC can reach home | Both on same network |
| **Firewall** | Outbound only | Inbound required |
| **Port Forwarding** | Raspberry Pi (home) | Work PC (harder) |
| **Corporate Networks** | ✅ Usually works | ❌ Often blocked |

---

## Next Steps

Once everything is working:

1. **Test Status Changes**: Change your Teams status and watch the LEDs update
2. **Set Up Auto-Start**: Configure systemd and Task Scheduler for automatic startup
3. **Customize Animations**: Try different animation modes to find your favorite
4. **Monitor Performance**: Check if work PC firewall allows sustained connections

---

## Support

For issues specific to push architecture:
- Check Work PC can reach home network
- Verify port forwarding configuration
- Test with `curl` or `Invoke-RestMethod` from work PC

For general hardware/setup issues, see [RASPBERRY_PI_SETUP.md](RASPBERRY_PI_SETUP.md)

---

**You're all set!** Your work PC will now push Teams status updates to your Raspberry Pi at home every 5 seconds. 🚀🌈
