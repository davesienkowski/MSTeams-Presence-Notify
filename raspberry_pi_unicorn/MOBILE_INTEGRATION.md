# Mobile Integration Setup Guide

Complete guide for adding mobile viewing, push notifications, and Home Assistant integration to your Teams Presence monitor.

## 🎯 What You Get

This integrated solution adds three powerful features to your Raspberry Pi + Unicorn HAT setup:

1. **📱 Mobile Web Dashboard** - View current status from any device on your network
2. **🔔 Push Notifications** - Get alerts when your status changes
3. **🏠 Home Assistant Integration** - Control smart home based on Teams status

## 📋 Prerequisites

- Raspberry Pi 3 B+ (or newer) with Unicorn HAT (already working)
- Raspberry Pi OS with internet connection
- Windows PC running the PowerShell status server
- Mobile device with internet access

## 🚀 Quick Start (5 Minutes)

### Step 1: Install Dependencies

```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
sudo pip3 install -r requirements_integrated.txt
```

### Step 2: Configure Settings

```bash
cp config.yaml config.yaml.backup
nano config.yaml
```

**Minimum required changes:**

1. Replace `YOUR_PC_IP` with your Windows PC's IP address
2. Change `ntfy_topic` to something unique (e.g., `myteamspresence_yourname_12345`)

Example:
```yaml
server:
  url: "http://192.168.1.100:8080/status"  # Your PC's IP

notifications:
  ntfy_topic: "myteamspresence_john_12345"  # Make this unique!
```

Save and exit (Ctrl+X, Y, Enter)

### Step 3: Run the Integrated Service

```bash
sudo python3 teams_status_integrated.py
```

You should see:
```
MS Teams Presence - Complete Integrated Solution
============================================================
Teams Server: http://192.168.1.100:8080/status
Poll Interval: 5 seconds
Animation Mode: pulse
Brightness: 50%

Integrations:
  Web Dashboard: ✓ Enabled
    → http://0.0.0.0:5000
  Push Notifications: ✓ Enabled
    → ntfy.sh/myteamspresence_john_12345
  Home Assistant: ✗ Disabled
```

### Step 4: Access from Your Mobile

**Find your Raspberry Pi's IP address:**
```bash
hostname -I
```

**Open on your phone:** `http://[raspberry-pi-ip]:5000`

Example: `http://192.168.1.50:5000`

✅ You should see a beautiful dashboard with your current Teams status!

## 📱 Mobile Web Dashboard Features

### What It Shows

- 🎨 **Large status display** with color-coded background
- ⏰ **Last update time** with auto-refresh
- 📊 **Uptime tracker** showing how long the monitor has been running
- 📈 **Change counter** tracking status changes
- 📜 **Recent history** showing last 10 status changes

### Progressive Web App (PWA)

You can **add to home screen** on iOS/Android:

**iPhone/iPad:**
1. Open the dashboard in Safari
2. Tap the Share button
3. Select "Add to Home Screen"
4. Tap "Add"

**Android:**
1. Open the dashboard in Chrome
2. Tap the menu (⋮)
3. Select "Add to Home Screen"
4. Tap "Add"

Now you have a full-screen app that looks native!

### Auto-Refresh

The dashboard automatically updates every 3 seconds without reloading the page.

## 🔔 Push Notifications Setup

### Option 1: Using ntfy.sh (Free & Easy - Recommended)

**On Your Mobile Device:**

1. **Install ntfy app:**
   - **Android**: [Google Play Store](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
   - **iOS**: [Apple App Store](https://apps.apple.com/us/app/ntfy/id1625396347)

2. **Subscribe to your topic:**
   - Open ntfy app
   - Tap "+" or "Subscribe to topic"
   - Enter your topic name (e.g., `myteamspresence_john_12345`)
   - Tap "Subscribe"

3. **Enable notifications:**
   - Make sure app notifications are enabled in your phone settings
   - Set notification importance to "High" for instant delivery

**Test it:**

Change your Teams status, and within 1-2 seconds you should receive a push notification!

Notification format:
```
🟢 Your Teams status is now: Available
🔴 Your Teams status is now: Busy
🟡 Your Teams status is now: Away
```

### Option 2: Self-Hosted ntfy.sh (Advanced)

If you want full control and privacy:

```bash
# Install ntfy server on a server/VPS
wget https://github.com/binwiederhier/ntfy/releases/download/v2.7.0/ntfy_2.7.0_linux_amd64.tar.gz
tar xzf ntfy_2.7.0_linux_amd64.tar.gz
./ntfy serve
```

Update `config.yaml`:
```yaml
notifications:
  ntfy_server: "https://your-ntfy-server.com"
```

See [ntfy.sh documentation](https://docs.ntfy.sh/) for full setup.

### Notification Settings

**Only notify on status changes:**
```yaml
notifications:
  only_on_change: true  # Don't spam on every poll
```

**Disable notifications temporarily:**
```yaml
notifications:
  enabled: false
```

## 🏠 Home Assistant Integration

### Prerequisites

- Home Assistant installation with MQTT broker (Mosquitto)
- MQTT integration configured in Home Assistant

### Step 1: Setup MQTT Broker in Home Assistant

If you haven't already:

1. Go to **Settings → Add-ons → Add-on Store**
2. Install **Mosquitto broker**
3. Start the add-on
4. Go to **Settings → Devices & Services → Add Integration**
5. Search for and add **MQTT**

### Step 2: Configure MQTT in config.yaml

```yaml
homeassistant:
  enabled: true
  mqtt_broker: "homeassistant.local"  # or your HA IP
  mqtt_port: 1883
  mqtt_username: "your_mqtt_user"     # if you set up auth
  mqtt_password: "your_mqtt_password"
```

### Step 3: Restart the Service

```bash
sudo systemctl restart teams-presence
```

### Step 4: Check Home Assistant

The sensor should automatically appear:

**Entity ID:** `sensor.teams_presence_status`

**Check in Developer Tools:**
1. Go to **Developer Tools → States**
2. Search for `sensor.teams_presence_status`
3. You should see your current status

### Using in Home Assistant

#### Example 1: Turn on red light when busy

```yaml
automation:
  - alias: "Office Light - Teams Busy"
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
          brightness: 255
```

#### Example 2: Notify family when available

```yaml
automation:
  - alias: "Notify Family - Available"
    trigger:
      - platform: state
        entity_id: sensor.teams_presence_status
        to: "Available"
    action:
      - service: notify.mobile_app_family
        data:
          message: "Dad is now available!"
          title: "Teams Status"
```

#### Example 3: Display on dashboard

```yaml
type: entities
entities:
  - entity: sensor.teams_presence_status
    name: Dave's Teams Status
    icon: mdi:microsoft-teams
```

#### Example 4: Smart home scene based on status

```yaml
automation:
  - alias: "Do Not Disturb Mode"
    trigger:
      - platform: state
        entity_id: sensor.teams_presence_status
        to: "InAMeeting"
    action:
      - scene: scene.do_not_disturb
      # Turns off doorbell, mutes speakers, dims lights
```

### Available Attributes

The sensor provides these attributes you can use in automations:

```yaml
status: "Busy"
emoji: "🔴"
color: "#FF0000"
last_update: "2025-01-20T14:30:45"
uptime: "2h 15m"
```

Access in templates:
```yaml
{{ state_attr('sensor.teams_presence_status', 'emoji') }}
{{ state_attr('sensor.teams_presence_status', 'color') }}
```

## 🔧 Advanced Configuration

### API Endpoints

The web server exposes several API endpoints:

**Get current status (JSON):**
```
http://[raspberry-pi-ip]:5000/api/status
```

Response:
```json
{
  "availability": "Busy",
  "timestamp": "2025-01-20T14:30:45.123456",
  "uptime": "2h 15m",
  "uptime_seconds": 8100,
  "emoji": "🔴",
  "color": "#FF0000",
  "change_count": 12
}
```

**Get status history:**
```
http://[raspberry-pi-ip]:5000/api/history
```

**Get configuration:**
```
http://[raspberry-pi-ip]:5000/api/config
```

### Integration with Other Services

You can integrate with any service that can make HTTP requests:

**IFTTT Webhook:**
```bash
curl -X POST "https://maker.ifttt.com/trigger/teams_status/with/key/YOUR_KEY" \
  -d "value1=Busy&value2=2025-01-20&value3=14:30"
```

**Node-RED Flow:**
```json
[
  {
    "id": "http-request",
    "type": "http request",
    "method": "GET",
    "url": "http://192.168.1.50:5000/api/status",
    "interval": 5000
  }
]
```

**Zapier Integration:**
Use "Webhooks by Zapier" trigger with the API endpoint.

## 🔐 Security Considerations

### Local Network Only (Recommended)

By default, the service only listens on your local network. This is secure for home use.

### Adding Authentication (Optional)

If you want to expose the service publicly, add authentication:

```python
# In teams_status_integrated.py, add:
from flask_httpauth import HTTPBasicAuth
auth = HTTPBasicAuth()

@auth.verify_password
def verify_password(username, password):
    return username == "your_username" and password == "your_password"

@app.route('/')
@auth.login_required
def index():
    # ... existing code
```

### SSL/HTTPS (Advanced)

For production deployment with SSL:

```bash
sudo apt-get install nginx
sudo certbot --nginx -d your-domain.com
```

Configure nginx as reverse proxy to Flask.

## 🚀 Auto-Start on Boot

Create systemd service:

```bash
sudo nano /etc/systemd/system/teams-presence.service
```

Add:
```ini
[Unit]
Description=MS Teams Presence Monitor
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn
ExecStart=/usr/bin/python3 /home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn/teams_status_integrated.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable teams-presence.service
sudo systemctl start teams-presence.service
```

Check status:
```bash
sudo systemctl status teams-presence.service
```

View logs:
```bash
sudo journalctl -u teams-presence.service -f
```

## 🐛 Troubleshooting

### Web Dashboard Not Loading

**Check if service is running:**
```bash
sudo systemctl status teams-presence
```

**Check firewall:**
```bash
sudo ufw allow 5000/tcp
```

**Check if port is listening:**
```bash
sudo netstat -tlnp | grep 5000
```

### Push Notifications Not Working

**Test ntfy.sh connection:**
```bash
curl -d "Test notification" https://ntfy.sh/your_topic_name
```

**Check your topic name is unique** - if someone else uses the same topic, you'll get their notifications!

**Verify app notifications enabled** in phone settings.

### Home Assistant Not Detecting Sensor

**Check MQTT connection:**
```bash
mosquitto_sub -h homeassistant.local -t "homeassistant/#" -v
```

**Republish discovery:**
Restart the service to republish discovery messages.

**Check MQTT integration** is properly configured in Home Assistant.

### Can't Connect to PowerShell Server

**Verify server is running:**
```powershell
# On Windows PC
Test-NetConnection -ComputerName localhost -Port 8080
```

**Check firewall rule:**
```powershell
Get-NetFirewallRule -DisplayName "Teams Status Server"
```

**Test from Raspberry Pi:**
```bash
curl http://YOUR_PC_IP:8080/status
```

## 📊 Performance & Resource Usage

**Typical resource usage:**
- CPU: ~5-10% (during animations)
- RAM: ~50-80 MB
- Network: < 1 KB/s
- Disk: Minimal (log files only)

**Power consumption:**
- Raspberry Pi 3 B+: ~2.5W idle, ~4W with animations
- Unicorn HAT: ~1-3W depending on brightness

## 🎨 Customization

### Change Animation Mode

Edit `config.yaml`:
```yaml
unicorn:
  animation_mode: "ripple"  # Try: solid, pulse, gradient, ripple, spinner
```

### Adjust Brightness

```yaml
unicorn:
  brightness: 0.3  # 0.0 (off) to 1.0 (full)
```

### Change Web Server Port

```yaml
web:
  port: 8080  # Use different port if 5000 is taken
```

### Custom Dashboard Colors

Edit the `HTML_TEMPLATE` in `teams_status_integrated.py` to customize colors, fonts, and layout.

## 🤝 Integration Examples

### Example 1: Slack Status Sync

Sync your Teams status to Slack using the API endpoint:

```python
import requests

teams_status = requests.get('http://raspberry-pi:5000/api/status').json()
slack_status = {
    'Available': {'status_text': 'Available', 'status_emoji': ':large_green_circle:'},
    'Busy': {'status_text': 'In a meeting', 'status_emoji': ':red_circle:'},
    'Away': {'status_text': 'Away from desk', 'status_emoji': ':yellow_circle:'}
}

# Update Slack profile (requires Slack API token)
requests.post('https://slack.com/api/users.profile.set',
    headers={'Authorization': f'Bearer {SLACK_TOKEN}'},
    json={'profile': slack_status.get(teams_status['availability'])})
```

### Example 2: Smart Display Integration

Show your status on a smart display using Google Home or Alexa via Home Assistant:

```yaml
automation:
  - alias: "Announce Teams Status"
    trigger:
      - platform: state
        entity_id: sensor.teams_presence_status
    action:
      - service: tts.google_say
        data:
          entity_id: media_player.living_room_display
          message: "Teams status changed to {{ states('sensor.teams_presence_status') }}"
```

### Example 3: Physical Sign Integration

Control a physical "On Air" sign when in meetings:

```yaml
automation:
  - alias: "On Air Sign"
    trigger:
      - platform: state
        entity_id: sensor.teams_presence_status
    action:
      - service: switch.turn_{{ 'on' if trigger.to_state.state in ['Busy', 'InAMeeting', 'InACall'] else 'off' }}
        target:
          entity_id: switch.on_air_sign
```

## 📚 Additional Resources

- [ntfy.sh Documentation](https://docs.ntfy.sh/)
- [Home Assistant MQTT Integration](https://www.home-assistant.io/integrations/mqtt/)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Raspberry Pi GPIO Pinout](https://pinout.xyz/)

## 💡 Tips & Best Practices

1. **Use a unique ntfy topic name** to avoid receiving notifications from others
2. **Set brightness to 0.3-0.5** for comfortable viewing and longer LED life
3. **Enable auto-start** so it runs after power loss
4. **Monitor logs** occasionally to catch any issues early
5. **Back up your config.yaml** before making changes
6. **Use static IP** for your Raspberry Pi for easier access

## 🎉 You're All Set!

You now have a complete Teams presence monitoring system with:
- ✅ Beautiful 8x8 LED display on your desk
- ✅ Mobile web dashboard accessible from any device
- ✅ Push notifications on your phone
- ✅ Home Assistant integration for smart home automation

Enjoy your enhanced Teams presence monitor! 🚀
