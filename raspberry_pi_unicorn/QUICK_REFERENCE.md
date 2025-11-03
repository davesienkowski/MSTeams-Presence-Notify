# Quick Reference Card 📋

**MS Teams Presence - Complete Integrated Solution**

---

## 🚀 One-Command Installation

```bash
curl -sL https://raw.githubusercontent.com/yourusername/MSTeams-Presence-Notify/main/raspberry_pi_unicorn/install_integrated.sh | bash
```

Or manually:
```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
chmod +x install_integrated.sh
./install_integrated.sh
```

---

## ⚙️ Essential Commands

### Service Management
```bash
# Start
sudo systemctl start teams-presence

# Stop
sudo systemctl stop teams-presence

# Restart
sudo systemctl restart teams-presence

# Status
sudo systemctl status teams-presence

# Enable auto-start
sudo systemctl enable teams-presence

# Disable auto-start
sudo systemctl disable teams-presence
```

### View Logs
```bash
# Real-time logs
sudo journalctl -u teams-presence -f

# Last 50 lines
sudo journalctl -u teams-presence -n 50

# Today's logs
sudo journalctl -u teams-presence --since today
```

### Manual Run (for testing)
```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
sudo python3 teams_status_integrated.py
```

---

## 🔧 Configuration

### Quick Edit
```bash
nano ~/MSTeams-Presence-Notify/raspberry_pi_unicorn/config.yaml
sudo systemctl restart teams-presence  # Apply changes
```

### Essential Settings
```yaml
# PC IP address
server:
  url: "http://192.168.1.100:8080/status"

# Notification topic (MUST BE UNIQUE!)
notifications:
  ntfy_topic: "myteamspresence_yourname_12345"

# Home Assistant
homeassistant:
  enabled: true
  mqtt_broker: "homeassistant.local"
```

---

## 📱 Access Points

### Web Dashboard
```
http://[raspberry-pi-ip]:5000
```

Find your IP:
```bash
hostname -I
```

### API Endpoints
```bash
# Current status (JSON)
curl http://raspberry-pi:5000/api/status

# Status history
curl http://raspberry-pi:5000/api/history

# Configuration
curl http://raspberry-pi:5000/api/config
```

### Test ntfy.sh
```bash
curl -d "Test message" https://ntfy.sh/your_topic_name
```

---

## 🐛 Troubleshooting

### Check if running
```bash
sudo systemctl status teams-presence
ps aux | grep teams_status
```

### Check network connectivity
```bash
# Test PC connection
curl http://YOUR_PC_IP:8080/status

# Check if web server is listening
sudo netstat -tlnp | grep 5000

# Test MQTT (if using Home Assistant)
mosquitto_sub -h homeassistant.local -t "homeassistant/#" -v
```

### Common Fixes

**Service won't start:**
```bash
# Check Python dependencies
sudo pip3 install -r requirements_integrated.txt

# Check config syntax
python3 -c "import yaml; yaml.safe_load(open('config.yaml'))"
```

**Web dashboard not loading:**
```bash
# Allow firewall
sudo ufw allow 5000/tcp

# Check Flask is running
sudo lsof -i :5000
```

**No notifications:**
- Verify topic name is unique
- Install ntfy app on phone
- Enable notifications in phone settings
- Test with curl command above

**Home Assistant not detecting:**
```bash
# Verify MQTT broker
mosquitto_pub -h homeassistant.local -t "test" -m "test"

# Check credentials in config.yaml
# Restart Home Assistant after changes
```

---

## 📊 Status Codes

| Status | Color | LED | Emoji |
|--------|-------|-----|-------|
| Available | Green | 🟢 | 🟢 |
| Busy | Red | 🔴 | 🔴 |
| InAMeeting | Red | 🔴 | 🔴 |
| InACall | Red | 🔴 | 🔴 |
| Away | Yellow | 🟡 | 🟡 |
| BeRightBack | Yellow | 🟡 | 🟡 |
| DoNotDisturb | Purple | 🟣 | 🟣 |
| Offline | Gray | ⚫ | ⚫ |
| Unknown | White | ⚪ | ⚪ |

---

## 🎨 Animation Modes

Edit in `config.yaml`:
```yaml
unicorn:
  animation_mode: "pulse"  # Change this
```

Options:
- **solid** - Solid color (lowest power)
- **pulse** - Breathing effect (default, recommended)
- **gradient** - Vertical gradient
- **ripple** - Ripple from center
- **spinner** - Spinning line

---

## 🏠 Home Assistant Quick Config

### Sensor Entity
```
sensor.teams_presence_status
```

### Example Automation
```yaml
automation:
  - alias: "Office Light Red When Busy"
    trigger:
      - platform: state
        entity_id: sensor.teams_presence_status
        to: "Busy"
    action:
      - service: light.turn_on
        target:
          entity_id: light.office_light
        data:
          rgb_color: [255, 0, 0]
```

See `homeassistant_config_example.yaml` for 25+ examples!

---

## 📦 File Locations

```
~/MSTeams-Presence-Notify/raspberry_pi_unicorn/
├── teams_status_integrated.py  # Main application
├── config.yaml                 # Your configuration
├── requirements_integrated.txt # Dependencies
├── install_integrated.sh       # Installation script
├── README_INTEGRATED.md        # Quick start guide
├── MOBILE_INTEGRATION.md       # Complete guide
├── homeassistant_config_example.yaml  # HA examples
└── QUICK_REFERENCE.md          # This file
```

System files:
```
/etc/systemd/system/teams-presence.service  # Service definition
/var/log/syslog                              # System logs
```

---

## 🔗 Important URLs

**Project Repository:**
- https://github.com/yourusername/MSTeams-Presence-Notify

**External Services:**
- ntfy.sh: https://ntfy.sh
- ntfy app (Android): https://play.google.com/store/apps/details?id=io.heckel.ntfy
- ntfy app (iOS): https://apps.apple.com/us/app/ntfy/id1625396347

**Documentation:**
- ntfy docs: https://docs.ntfy.sh/
- Home Assistant MQTT: https://www.home-assistant.io/integrations/mqtt/
- Flask docs: https://flask.palletsprojects.com/

---

## 💡 Quick Tips

1. **Use a unique ntfy topic** - Avoid `myteamspresence` (too common!)
   ```
   Good: myteamspresence_john_doe_12345
   Bad:  myteamspresence
   ```

2. **Set static IP** for Raspberry Pi
   ```bash
   sudo nano /etc/dhcpcd.conf
   # Add: interface eth0
   #      static ip_address=192.168.1.50/24
   ```

3. **Add to phone home screen** for app-like experience
   - iOS: Safari → Share → Add to Home Screen
   - Android: Chrome → Menu → Add to Home screen

4. **Monitor resource usage**
   ```bash
   htop  # Press F10 to exit
   ```

5. **Backup config before changes**
   ```bash
   cp config.yaml config.yaml.backup
   ```

---

## 🆘 Getting Help

### Check Documentation
1. **README_INTEGRATED.md** - Quick start
2. **MOBILE_INTEGRATION.md** - Complete guide
3. **INTEGRATION_SUMMARY.md** - Overview

### Debug Steps
1. Check logs: `sudo journalctl -u teams-presence -f`
2. Test PC connection: `curl http://YOUR_PC_IP:8080/status`
3. Verify config: `nano config.yaml`
4. Restart service: `sudo systemctl restart teams-presence`

### Still Need Help?
- Open GitHub issue with:
  - Error logs
  - Config file (remove passwords!)
  - Steps to reproduce
  - Raspberry Pi model

---

## 📱 Mobile App Quick Setup

### ntfy.sh (Push Notifications)
1. Install ntfy app on phone
2. Tap "+" or "Subscribe to topic"
3. Enter topic from `config.yaml`
4. Done! Receive notifications

### Web Dashboard (PWA)
1. Open `http://raspberry-pi:5000` in browser
2. Add to home screen
3. Open like a native app

---

## ⚡ Performance Specs

| Metric | Value |
|--------|-------|
| Startup time | < 5 seconds |
| Status update | Every 5 seconds |
| Web refresh | Every 3 seconds |
| Push notification delay | 1-2 seconds |
| MQTT update delay | < 100ms |
| CPU usage | 5-10% |
| RAM usage | 50-80 MB |
| Network usage | < 1 KB/s |

---

## 🎯 Common Tasks

### Change Teams Server IP
```bash
nano config.yaml
# Update server.url
sudo systemctl restart teams-presence
```

### Change Web Port
```bash
nano config.yaml
# Update web.port
sudo systemctl restart teams-presence
```

### Disable Notifications
```bash
nano config.yaml
# Set notifications.enabled: false
sudo systemctl restart teams-presence
```

### Enable Home Assistant
```bash
nano config.yaml
# Set homeassistant.enabled: true
# Configure MQTT settings
sudo systemctl restart teams-presence
```

### Change LED Brightness
```bash
nano config.yaml
# Update unicorn.brightness (0.0 to 1.0)
sudo systemctl restart teams-presence
```

---

## 🔄 Update Process

```bash
# Pull latest code
cd ~/MSTeams-Presence-Notify
git pull

# Update dependencies
cd raspberry_pi_unicorn
sudo pip3 install --upgrade -r requirements_integrated.txt

# Restart service
sudo systemctl restart teams-presence

# Check status
sudo systemctl status teams-presence
```

---

## 📋 Pre-flight Checklist

Before starting:
- [ ] Raspberry Pi with Unicorn HAT assembled
- [ ] Raspberry Pi OS installed and updated
- [ ] Connected to network (WiFi or Ethernet)
- [ ] Windows PC running PowerShell status server
- [ ] PC IP address known
- [ ] Firewall rule created on PC (port 8080)

After installation:
- [ ] Service running: `sudo systemctl status teams-presence`
- [ ] Web dashboard accessible: `http://raspberry-pi:5000`
- [ ] ntfy app installed and subscribed
- [ ] LED shows current status
- [ ] Notifications working

---

**Keep this reference handy! 📌**

Save to:
- Phone notes app
- Print and tape to desk
- Bookmark in browser
- Add to password manager notes

---

*Last updated: 2025-01-20*
