# MS Teams Presence - Complete Integrated Solution (PUSH Architecture) 🚀

**Raspberry Pi + Unicorn HAT + Web Dashboard + Push Notifications + Home Assistant**

**Architecture:** Work PC PUSHES status → Raspberry Pi receives and displays

---

## 🏗️ Architecture Overview

```
Work PC (Windows at office/work)
├── TeamsPushClient.ps1 (monitors Teams logs)
└── PUSHES status via HTTP POST
         ↓
         ↓ POST http://RASPBERRY_PI_IP:8080/status
         ↓
Raspberry Pi (at home/desk)
├── HTTP Server (receives status on port 8080)
├── Unicorn HAT display
├── Web Dashboard (port 5000) → Mobile devices
├── Push Notifications → ntfy.sh → Phone
└── MQTT → Home Assistant → Smart home
```

**Key Point:** Unlike typical setups where the Raspberry Pi fetches status, your **work PC pushes updates** to the Raspberry Pi. This works great even if they're on different networks!

---

## ✨ Features

### 🌈 **Unicorn HAT Display**
- 8x8 RGB LED matrix showing Teams status
- Multiple animation modes
- Color-coded status matching Microsoft Teams

### 📱 **Mobile Web Dashboard**
- Beautiful mobile-friendly interface
- Real-time status updates
- Status history and uptime tracking
- Add to home screen as PWA

### 🔔 **Push Notifications**
- ntfy.sh integration (free, no signup)
- iOS and Android support
- Status change alerts

### 🏠 **Home Assistant Integration**
- MQTT auto-discovery
- Control smart lights based on status
- Do Not Disturb automation
- Family notifications

---

## 🚀 Quick Start

### Step 1: Setup Raspberry Pi (Home/Desk)

```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn

# Install dependencies
sudo pip3 install -r requirements_integrated.txt

# Configure
cp config_push.yaml config_push.yaml.example
nano config_push.yaml
# Change: ntfy_topic to something unique!

# Run
sudo python3 teams_status_integrated_push.py
```

You should see:
```
Server listening on port: 8080
Work PC should POST to: http://<raspberry-pi-ip>:8080/status
```

**Note your Raspberry Pi's IP address:**
```bash
hostname -I
```

### Step 2: Setup Work PC (Windows)

**Edit the push client script:**

```powershell
cd D:\Repos\MSTeams-Presence-Notify\powershell_service
notepad TeamsPushClient.ps1
```

**Change line 6 to your Raspberry Pi's IP:**
```powershell
[string]$RaspberryPiIP = "192.168.50.137",  # Change to YOUR Pi's IP
```

**Run the push client:**
```powershell
powershell -ExecutionPolicy Bypass -File TeamsPushClient.ps1
```

You should see status updates being sent!

---

## 📱 Mobile Access

### Web Dashboard

**From any device, open:**
```
http://[raspberry-pi-ip]:5000
```

Example: `http://192.168.50.137:5000`

### Push Notifications

1. **Install ntfy app:**
   - [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
   - [iOS](https://apps.apple.com/us/app/ntfy/id1625396347)

2. **Subscribe to your topic** (from `config_push.yaml`)

3. **Done!** You'll receive push notifications

---

## 🏠 Home Assistant Setup

### Enable in config

Edit `config_push.yaml`:
```yaml
homeassistant:
  enabled: true
  mqtt_broker: "homeassistant.local"  # or your HA IP
  mqtt_port: 1883
  mqtt_username: "your_user"          # if using auth
  mqtt_password: "your_pass"
```

Restart the service:
```bash
sudo systemctl restart teams-presence-push
```

The sensor will appear as: `sensor.teams_presence_status`

---

## 🔧 Configuration

### Minimum Setup (config_push.yaml)

```yaml
# Server settings - Raspberry Pi listens on this port
server:
  port: 8080  # Work PC posts to this port

# Change this to something unique!
notifications:
  ntfy_topic: "myteamspresence_yourname_12345"
```

### Full Configuration

See [config_push.yaml](config_push.yaml) for all options including:
- LED brightness and animation modes
- Web dashboard settings
- Push notification configuration
- Home Assistant MQTT settings

---

## 🛠️ Installation as Service

### Create systemd service:

```bash
sudo nano /etc/systemd/system/teams-presence-push.service
```

```ini
[Unit]
Description=MS Teams Presence (PUSH)
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn
ExecStart=/usr/bin/python3 /home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn/teams_status_integrated_push.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable teams-presence-push
sudo systemctl start teams-presence-push
```

### Check status:

```bash
sudo systemctl status teams-presence-push
sudo journalctl -u teams-presence-push -f
```

---

## 🐛 Troubleshooting

### Raspberry Pi not receiving updates?

**Check if server is running:**
```bash
sudo systemctl status teams-presence-push
sudo netstat -tlnp | grep 8080
```

**Test from work PC:**
```powershell
Invoke-RestMethod -Uri "http://RASPBERRY_PI_IP:8080/" -Method GET
```

**Check firewall on Raspberry Pi:**
```bash
sudo ufw allow 8080/tcp
```

### Work PC can't reach Raspberry Pi?

**Different networks?** This is actually fine! The work PC just needs outbound internet access to reach your home Raspberry Pi.

**If Raspberry Pi is at home:** You need to setup port forwarding:
1. Forward port 8080 on your home router → Raspberry Pi
2. Use your home's external IP in `TeamsPushClient.ps1`
3. **Security:** Consider using a VPN or SSH tunnel instead!

**Security recommendation:**
```bash
# On Raspberry Pi, setup SSH tunnel
ssh -R 8080:localhost:8080 user@work-pc

# Or use a VPN (better)
```

### Push notifications not working?

- Verify topic is unique
- Test manually:
  ```bash
  curl -d "Test" https://ntfy.sh/your_topic_name
  ```
- Check app notifications are enabled

### Web dashboard not loading?

```bash
# Check Flask is running
sudo lsof -i :5000

# Allow firewall
sudo ufw allow 5000/tcp
```

---

## 📊 Architecture Benefits

### Why PUSH is Better (Your Setup)

✅ **Works across networks** - Work PC at office, Pi at home
✅ **Simpler networking** - Work PC doesn't need to run a server
✅ **Lower latency** - Updates sent immediately when status changes
✅ **Firewall friendly** - Only outbound connections from work PC
✅ **Remote accessible** - No VPN needed to your office network

### vs. PULL Architecture (Alternate Setup)

The other common approach (not yours):
- Raspberry Pi fetches FROM work PC
- Requires both on same network
- Work PC runs HTTP server
- Pi polls every N seconds

**Your PUSH setup is better for work-from-office scenarios!**

---

## 🔐 Security Considerations

### Current Setup (Basic)

- Work PC → Raspberry Pi: Unencrypted HTTP
- Acceptable for: Same network or trusted home connection
- Risk: Status data visible if intercepted

### Enhanced Security (Optional)

**Option 1: SSH Tunnel**
```bash
# On work PC, setup SSH tunnel
ssh -R 8080:localhost:8080 user@raspberry-pi
```

**Option 2: VPN**
```bash
# Setup WireGuard or OpenVPN
# Work PC and Pi on same virtual network
```

**Option 3: HTTPS with Authentication**
- Add SSL certificate to Raspberry Pi
- Add authentication to POST endpoint
- See advanced setup guide

---

## 📚 Files Reference

### On Work PC (Windows)
- **TeamsPushClient.ps1** - Monitors Teams and pushes status

### On Raspberry Pi
- **teams_status_integrated_push.py** - Main application
- **config_push.yaml** - Configuration file
- **requirements_integrated.txt** - Python dependencies

### Documentation
- **README_INTEGRATED_PUSH.md** - This file
- **MOBILE_INTEGRATION_PUSH.md** - Complete setup guide
- **homeassistant_config_example.yaml** - HA automations

---

## 🎯 What's Next?

1. **Secure the connection** (VPN or SSH tunnel)
2. **Setup auto-start** on both PC and Pi
3. **Create Home Assistant automations**
4. **Add custom notifications** for specific scenarios
5. **Monitor logs** to ensure reliability

---

## 💡 Tips

- **Unique ntfy topic:** Never use default names!
- **Static IP for Pi:** Makes configuration easier
- **Monitor work PC:** Ensure push client stays running
- **Test failover:** What happens if Pi goes offline?
- **Backup config:** Before making changes

---

## 🆘 Getting Help

### Check Logs

**Raspberry Pi:**
```bash
sudo journalctl -u teams-presence-push -f
```

**Work PC:**
- Check PowerShell window for errors
- Look for "Successfully connected" message

### Common Issues

1. **Connection refused**: Check firewall rules
2. **No updates**: Verify Teams is running on work PC
3. **Wrong status**: Check Teams log parsing in push client
4. **Notifications not working**: Verify unique topic name

---

**Enjoy your Teams presence monitoring system!** 🚀
