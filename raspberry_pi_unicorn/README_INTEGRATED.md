# MS Teams Presence - Complete Integrated Solution 🚀

**Raspberry Pi + Unicorn HAT + Web Dashboard + Push Notifications + Home Assistant**

Transform your Teams presence monitor into a complete notification system with mobile access and smart home integration!

---

## ✨ Features

### 🌈 **Unicorn HAT Display** (Original)
- 8x8 RGB LED matrix showing your Teams status
- Multiple animation modes (pulse, ripple, gradient, spinner, solid)
- Color-coded status matching Microsoft Teams

### 📱 **Mobile Web Dashboard** (NEW!)
- Beautiful mobile-friendly web interface
- Real-time status updates (auto-refresh every 3 seconds)
- Status history tracking
- Uptime and change counter
- Accessible from any device on your network
- Progressive Web App (add to home screen!)

### 🔔 **Push Notifications** (NEW!)
- Get notified when your Teams status changes
- Uses ntfy.sh (free, no signup required)
- iOS and Android support
- Configurable notification settings

### 🏠 **Home Assistant Integration** (NEW!)
- Full MQTT integration with auto-discovery
- Control smart lights based on Teams status
- Do Not Disturb automation when in meetings
- Family notifications
- Complete smart home scenes

---

## 🎯 Quick Start

### One-Line Installation

```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
chmod +x install_integrated.sh
./install_integrated.sh
```

The installer will:
1. ✅ Install all dependencies
2. ✅ Configure your settings
3. ✅ Set up auto-start on boot
4. ✅ Test the connection
5. ✅ Start the service

### Manual Installation

```bash
# Install dependencies
sudo pip3 install -r requirements_integrated.txt

# Configure
cp config.yaml config.yaml.example
nano config.yaml  # Edit your settings

# Run
sudo python3 teams_status_integrated.py
```

---

## 📱 Accessing Your Dashboard

**Find your Raspberry Pi's IP:**
```bash
hostname -I
```

**Open on any device:**
```
http://[raspberry-pi-ip]:5000
```

Example: `http://192.168.1.50:5000`

**Add to home screen** for a native app experience!

---

## 🔔 Setting Up Push Notifications

### On Your Mobile Device

1. **Install ntfy app:**
   - [Android (Google Play)](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
   - [iOS (App Store)](https://apps.apple.com/us/app/ntfy/id1625396347)

2. **Subscribe to your topic:**
   - Open ntfy app
   - Tap "+" or "Subscribe to topic"
   - Enter your unique topic from `config.yaml`
   - Tap "Subscribe"

3. **Done!** You'll now receive push notifications when your Teams status changes.

**Example notification:**
```
🟢 Your Teams status is now: Available
```

---

## 🏠 Home Assistant Setup

### Quick Setup

1. **Edit config.yaml:**
```yaml
homeassistant:
  enabled: true
  mqtt_broker: "homeassistant.local"
  mqtt_port: 1883
  mqtt_username: "your_mqtt_user"      # if using auth
  mqtt_password: "your_mqtt_password"
```

2. **Restart the service:**
```bash
sudo systemctl restart teams-presence
```

3. **Check Home Assistant:**
- The sensor will auto-appear as `sensor.teams_presence_status`
- Go to Developer Tools → States to verify

### Example Automations

**Turn office light red when in a meeting:**
```yaml
automation:
  - alias: "Office Light - Teams Busy"
    trigger:
      - platform: state
        entity_id: sensor.teams_presence_status
        to: "InAMeeting"
    action:
      - service: light.turn_on
        target:
          entity_id: light.office_light
        data:
          rgb_color: [255, 0, 0]
```

**See [homeassistant_config_example.yaml](homeassistant_config_example.yaml) for 25+ automation examples!**

---

## ⚙️ Configuration

All settings in `config.yaml`:

```yaml
# Teams status server
server:
  url: "http://YOUR_PC_IP:8080/status"
  poll_interval: 5

# LED display
unicorn:
  brightness: 0.5
  animation_mode: "pulse"  # solid, pulse, gradient, ripple, spinner

# Web dashboard
web:
  enabled: true
  port: 5000

# Push notifications
notifications:
  enabled: true
  ntfy_topic: "myteamspresence_yourname"
  only_on_change: true

# Home Assistant
homeassistant:
  enabled: false
  mqtt_broker: "homeassistant.local"
```

---

## 🔧 Service Management

If installed as a service:

```bash
# Check status
sudo systemctl status teams-presence

# View logs
sudo journalctl -u teams-presence -f

# Restart
sudo systemctl restart teams-presence

# Stop
sudo systemctl stop teams-presence

# Disable auto-start
sudo systemctl disable teams-presence
```

---

## 📊 API Endpoints

The web server exposes REST APIs:

**Current status:**
```bash
curl http://raspberry-pi:5000/api/status
```

Response:
```json
{
  "availability": "Busy",
  "timestamp": "2025-01-20T14:30:45",
  "emoji": "🔴",
  "color": "#FF0000",
  "uptime": "2h 15m",
  "change_count": 12
}
```

**Status history:**
```bash
curl http://raspberry-pi:5000/api/history
```

**Configuration:**
```bash
curl http://raspberry-pi:5000/api/config
```

---

## 🎨 Customization

### Change Animation Mode

Edit `config.yaml`:
```yaml
unicorn:
  animation_mode: "ripple"  # Try different modes!
```

Available modes:
- **solid** - Solid color (lowest power)
- **pulse** - Breathing effect (recommended)
- **gradient** - Vertical gradient
- **ripple** - Ripple from center
- **spinner** - Spinning line

### Adjust Brightness

```yaml
unicorn:
  brightness: 0.3  # 0.0 to 1.0
```

Lower brightness = longer LED life + less power consumption

---

## 🐛 Troubleshooting

### Web dashboard not loading?

```bash
# Check if service is running
sudo systemctl status teams-presence

# Check if port is listening
sudo netstat -tlnp | grep 5000

# Check firewall
sudo ufw allow 5000/tcp
```

### Push notifications not working?

- **Check topic is unique** (avoid common names!)
- **Verify app notifications enabled** in phone settings
- **Test manually:**
  ```bash
  curl -d "Test" https://ntfy.sh/your_topic_name
  ```

### Home Assistant not detecting sensor?

- **Verify MQTT broker** is running
- **Check credentials** in config.yaml
- **Republish discovery:**
  ```bash
  sudo systemctl restart teams-presence
  ```
- **Monitor MQTT:**
  ```bash
  mosquitto_sub -h homeassistant.local -t "homeassistant/#" -v
  ```

### Can't connect to PowerShell server?

- **Verify server is running** on Windows PC
- **Check firewall rule:**
  ```powershell
  Get-NetFirewallRule -DisplayName "Teams Status Server"
  ```
- **Test from Raspberry Pi:**
  ```bash
  curl http://YOUR_PC_IP:8080/status
  ```

---

## 📚 Documentation

- **[MOBILE_INTEGRATION.md](MOBILE_INTEGRATION.md)** - Complete setup guide with examples
- **[homeassistant_config_example.yaml](homeassistant_config_example.yaml)** - 25+ automation examples
- **[config.yaml](config.yaml)** - Full configuration reference

---

## 🎉 What's Next?

**Ideas for further integration:**

1. **Sync with Slack/Discord** using the API
2. **Smart display** announcements via Google Home/Alexa
3. **Physical "On Air" sign** controlled by Home Assistant
4. **Productivity tracking** logging to Google Sheets
5. **Wearable integration** for smartwatches
6. **Voice commands** via Home Assistant

---

## 💡 Tips

- Use a **unique ntfy topic** to avoid receiving others' notifications
- Set **brightness to 0.3-0.5** for comfortable viewing
- Enable **auto-start** for reliability after power loss
- Use **static IP** for your Raspberry Pi
- **Back up config.yaml** before making changes

---

## 🤝 Contributing

Found a bug or have a feature request? Please open an issue!

---

## 📝 License

MIT License - See LICENSE file for details

---

**Enjoy your complete Teams presence monitoring system!** 🚀
