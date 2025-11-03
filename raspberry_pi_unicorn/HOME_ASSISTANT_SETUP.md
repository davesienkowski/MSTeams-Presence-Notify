# Home Assistant Setup Guide - Teams Presence Integration

Complete guide to integrate your Teams presence monitor with Home Assistant via MQTT.

---

## 📋 Prerequisites

Before starting, you need:
- ✅ Home Assistant installed and running
- ✅ MQTT broker (Mosquitto) installed
- ✅ Raspberry Pi Teams presence monitor working

---

## 🔧 Step 1: Install MQTT Broker in Home Assistant

### Option A: Using Add-ons (Recommended for Home Assistant OS)

1. **Open Home Assistant**
2. **Go to:** Settings → Add-ons → Add-on Store
3. **Search for:** "Mosquitto broker"
4. **Click:** Install
5. **Configure** (usually default settings work):
   ```yaml
   logins: []
   require_certificate: false
   certfile: fullchain.pem
   keyfile: privkey.pem
   customize:
     active: false
     folder: mosquitto
   ```
6. **Start** the add-on
7. **Enable:** "Start on boot" and "Watchdog"

### Option B: Using Docker

```bash
docker run -d \
  --name mosquitto \
  -p 1883:1883 \
  -p 9001:9001 \
  -v /path/to/mosquitto/config:/mosquitto/config \
  -v /path/to/mosquitto/data:/mosquitto/data \
  -v /path/to/mosquitto/log:/mosquitto/log \
  eclipse-mosquitto
```

---

## 🔌 Step 2: Add MQTT Integration to Home Assistant

1. **Go to:** Settings → Devices & Services
2. **Click:** "+ Add Integration"
3. **Search for:** "MQTT"
4. **Select:** MQTT
5. **Configure:**
   - **Broker:** `localhost` (if on same machine) or `homeassistant.local`
   - **Port:** `1883`
   - **Username:** (leave blank if not set)
   - **Password:** (leave blank if not set)
6. **Click:** Submit

**Verify:** You should see "MQTT" integration in your integrations list.

---

## 🎯 Step 3: Enable Teams Presence in Raspberry Pi Config

### Edit Configuration

On your Raspberry Pi:

```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
nano config_push.yaml
```

### Update Home Assistant Section

```yaml
homeassistant:
  # Enable integration
  enabled: true

  # MQTT broker details
  mqtt_broker: "homeassistant.local"  # or IP like "192.168.1.100"
  mqtt_port: 1883

  # If you set up authentication on Mosquitto:
  mqtt_username: ""  # leave blank if no auth
  mqtt_password: ""  # leave blank if no auth

  # Topics (usually don't change these)
  mqtt_topic: "homeassistant/sensor/teams_presence"
  discovery_prefix: "homeassistant"
```

### Save and Restart

```bash
# If running as service
sudo systemctl restart teams-presence-push

# Or if running manually, stop and restart
```

---

## ✅ Step 4: Verify Sensor in Home Assistant

### Check MQTT Messages

1. **Go to:** Settings → Devices & Services → MQTT
2. **Click:** "Configure"
3. **Click:** "Listen to a topic"
4. **Enter topic:** `homeassistant/#`
5. **Click:** "Start Listening"

You should see messages like:
```json
{
  "topic": "homeassistant/sensor/teams_presence/config",
  "payload": {
    "name": "Teams Presence Status",
    "unique_id": "teams_presence_status",
    "state_topic": "homeassistant/sensor/teams_presence/state",
    ...
  }
}
```

### Find the Sensor

1. **Go to:** Developer Tools → States
2. **Search for:** `sensor.teams_presence_status`
3. **You should see:**
   ```
   sensor.teams_presence_status
   State: Available (or current status)
   Attributes:
     emoji: 🟢
     color: #00FF00
     uptime: 2h 15m
     last_update: 2025-01-20T14:30:45
   ```

---

## 🎨 Step 5: Add to Dashboard

### Option A: Simple Entity Card

1. **Edit Dashboard** (click 3 dots → Edit Dashboard)
2. **Add Card** → Entities
3. **Add Entity:** `sensor.teams_presence_status`
4. **Customize:**
   ```yaml
   type: entities
   title: Teams Presence
   entities:
     - entity: sensor.teams_presence_status
       name: Current Status
       icon: mdi:microsoft-teams
   ```

### Option B: Glance Card with Attributes

```yaml
type: glance
title: Teams Status
entities:
  - entity: sensor.teams_presence_status
    name: Status
  - entity: sensor.teams_presence_status
    name: Uptime
    attribute: uptime
  - entity: sensor.teams_presence_status
    name: Last Update
    attribute: last_update
```

### Option C: Markdown Card with Emoji

```yaml
type: markdown
content: |
  ## {{ state_attr('sensor.teams_presence_status', 'emoji') }} Teams Status

  **Current:** {{ states('sensor.teams_presence_status') }}

  **Uptime:** {{ state_attr('sensor.teams_presence_status', 'uptime') }}

  **Last Updated:** {{ state_attr('sensor.teams_presence_status', 'last_update') }}
```

---

## 🤖 Step 6: Create Automations

### Example 1: Turn Office Light Red When Busy

**UI Method:**
1. Settings → Automations & Scenes
2. Create Automation
3. Add Trigger → State
   - Entity: `sensor.teams_presence_status`
   - To: `Busy`
4. Add Action → Call Service
   - Service: `light.turn_on`
   - Target: `light.office_light`
   - Data:
     ```yaml
     rgb_color: [255, 0, 0]
     brightness: 255
     ```

**YAML Method:**
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
          transition: 1
```

### Example 2: Notify Family When Available

```yaml
automation:
  - alias: "Notify Family - Available for Dinner"
    trigger:
      - platform: state
        entity_id: sensor.teams_presence_status
        to: "Available"
    condition:
      - condition: time
        after: "17:00:00"
        before: "19:00:00"
    action:
      - service: notify.mobile_app_spouse_phone
        data:
          message: "Dad is available now!"
          title: "Teams Status"
```

### Example 3: Do Not Disturb Mode

```yaml
automation:
  - alias: "Do Not Disturb - Teams Meeting"
    trigger:
      - platform: state
        entity_id: sensor.teams_presence_status
        to:
          - "InAMeeting"
          - "InACall"
          - "DoNotDisturb"
    action:
      # Mute doorbell
      - service: switch.turn_off
        target:
          entity_id: switch.doorbell_chime

      # Lower speaker volume
      - service: media_player.volume_set
        target:
          entity_id: media_player.living_room_speaker
        data:
          volume_level: 0.1

      # Turn on "On Air" sign
      - service: switch.turn_on
        target:
          entity_id: switch.on_air_sign
```

### Example 4: Announce to Google Home

```yaml
automation:
  - alias: "Announce Meeting"
    trigger:
      - platform: state
        entity_id: sensor.teams_presence_status
        to: "InAMeeting"
    action:
      - service: tts.google_say
        target:
          entity_id: media_player.living_room_speaker
        data:
          message: "Please be quiet, Dad is in a meeting"
```

---

## 🎯 Advanced: Template Sensors

Create helper sensors based on Teams status:

### Configuration.yaml

```yaml
sensor:
  - platform: template
    sensors:
      # User-friendly status
      teams_status_friendly:
        friendly_name: "Teams Status"
        value_template: >-
          {% set status = states('sensor.teams_presence_status') %}
          {% if status == 'Available' %}
            Available to chat
          {% elif status == 'Busy' %}
            Busy - do not disturb
          {% elif status == 'InAMeeting' %}
            In a meeting
          {% elif status == 'InACall' %}
            On a call
          {% elif status == 'Away' %}
            Away from desk
          {% elif status == 'DoNotDisturb' %}
            Do not disturb
          {% else %}
            {{ status }}
          {% endif %}
        icon_template: mdi:microsoft-teams

      # Is user available? (binary)
      teams_is_available:
        friendly_name: "Is Available"
        value_template: >-
          {{ states('sensor.teams_presence_status') == 'Available' }}

      # Is user in meeting? (binary)
      teams_in_meeting:
        friendly_name: "In Meeting"
        value_template: >-
          {{ states('sensor.teams_presence_status') in ['InAMeeting', 'InACall'] }}
```

### Binary Sensors

```yaml
binary_sensor:
  - platform: template
    sensors:
      # Do not disturb mode active
      teams_do_not_disturb:
        friendly_name: "Teams Do Not Disturb"
        device_class: occupancy
        value_template: >-
          {{ states('sensor.teams_presence_status') in
             ['Busy', 'InAMeeting', 'InACall', 'DoNotDisturb'] }}

      # At desk indicator
      teams_at_desk:
        friendly_name: "At Desk"
        device_class: presence
        value_template: >-
          {{ states('sensor.teams_presence_status') not in
             ['Offline', 'Away', 'Unknown'] }}
```

---

## 🔧 Troubleshooting

### Sensor Not Appearing

**Check MQTT connection from Raspberry Pi:**
```bash
# On Raspberry Pi
sudo apt-get install mosquitto-clients

# Test publish
mosquitto_pub -h homeassistant.local -t "test" -m "Hello"

# Test subscribe
mosquitto_sub -h homeassistant.local -t "homeassistant/#" -v
```

**Check logs on Raspberry Pi:**
```bash
sudo journalctl -u teams-presence-push -f | grep -i mqtt
```

**Check Home Assistant logs:**
- Settings → System → Logs
- Look for MQTT-related errors

### Connection Refused

**Possible causes:**
1. MQTT broker not running
2. Wrong IP/hostname
3. Firewall blocking port 1883

**Test from Raspberry Pi:**
```bash
telnet homeassistant.local 1883
# Should connect (press Ctrl+C to exit)
```

**Check firewall:**
```bash
# On Home Assistant host
sudo ufw allow 1883/tcp
```

### Sensor Shows "Unknown" or "Unavailable"

**Check Raspberry Pi is running:**
```bash
sudo systemctl status teams-presence-push
```

**Check MQTT messages are being sent:**
```bash
mosquitto_sub -h homeassistant.local -t "homeassistant/sensor/teams_presence/#" -v
```

**Restart the service:**
```bash
sudo systemctl restart teams-presence-push
```

### Authentication Issues

If you set up authentication on Mosquitto, update `config_push.yaml`:

```yaml
homeassistant:
  mqtt_username: "your_username"
  mqtt_password: "your_password"
```

Then restart:
```bash
sudo systemctl restart teams-presence-push
```

---

## 📊 Monitoring & Debugging

### View MQTT Traffic in Home Assistant

1. Settings → Devices & Services → MQTT
2. Click "Configure"
3. Click "Listen to a topic"
4. Topic: `homeassistant/sensor/teams_presence/#`
5. Click "Start Listening"

You should see:
```
homeassistant/sensor/teams_presence/state: "Available"
homeassistant/sensor/teams_presence/attributes: {"emoji": "🟢", ...}
```

### Check Discovery Messages

Listen to topic: `homeassistant/sensor/teams_presence/config`

Should show:
```json
{
  "name": "Teams Presence Status",
  "unique_id": "teams_presence_status",
  "state_topic": "homeassistant/sensor/teams_presence/state",
  "json_attributes_topic": "homeassistant/sensor/teams_presence/attributes",
  "icon": "mdi:microsoft-teams"
}
```

---

## 🎨 Dashboard Examples

### Complete Teams Status Card

```yaml
type: vertical-stack
cards:
  # Status display
  - type: markdown
    content: |
      # {{ state_attr('sensor.teams_presence_status', 'emoji') }} Teams Status

      **Current:** {{ states('sensor.teams_presence_status') }}

      **Uptime:** {{ state_attr('sensor.teams_presence_status', 'uptime') }}

  # Details
  - type: entities
    entities:
      - entity: sensor.teams_presence_status
        name: Status
      - type: attribute
        entity: sensor.teams_presence_status
        attribute: last_update
        name: Last Update
      - entity: binary_sensor.teams_do_not_disturb
        name: DND Active
      - entity: binary_sensor.teams_at_desk
        name: At Desk

  # Quick actions
  - type: horizontal-stack
    cards:
      - type: button
        name: View History
        icon: mdi:history
        tap_action:
          action: navigate
          navigation_path: /history?entity_id=sensor.teams_presence_status
```

### Conditional Card (Only Show When In Meeting)

```yaml
type: conditional
conditions:
  - entity: sensor.teams_presence_status
    state_not: "Available"
card:
  type: markdown
  content: |
    ## ⚠️ Do Not Disturb

    **Status:** {{ states('sensor.teams_presence_status') }}

    Please do not interrupt!
```

---

## 🔐 Security Best Practices

### Use Authentication

**Create MQTT user:**

1. Open Mosquitto add-on configuration
2. Add user:
   ```yaml
   logins:
     - username: teams_presence
       password: your_secure_password
   ```
3. Restart Mosquitto

**Update Raspberry Pi config:**
```yaml
homeassistant:
  mqtt_username: "teams_presence"
  mqtt_password: "your_secure_password"
```

### Use SSL/TLS (Advanced)

For encrypted MQTT communication:

1. Setup SSL certificates in Home Assistant
2. Configure Mosquitto for TLS
3. Update Raspberry Pi to use port 8883

---

## 📱 Mobile App Integration

Use the sensor in Home Assistant mobile app:

### Notification on Status Change

```yaml
automation:
  - alias: "Mobile - Teams Status Changed"
    trigger:
      - platform: state
        entity_id: sensor.teams_presence_status
    action:
      - service: notify.mobile_app_your_phone
        data:
          message: "Teams status: {{ states('sensor.teams_presence_status') }}"
          title: "Status Update"
          data:
            tag: "teams_status"
            group: "teams"
            notification_icon: "mdi:microsoft-teams"
```

### Widget on Phone

Add sensor to Home Assistant widget on your phone home screen.

---

## 🎉 You're Done!

Your Teams presence is now integrated with Home Assistant!

**What you can do now:**
- ✅ View status on dashboard
- ✅ Create automations based on status
- ✅ Control smart home based on Teams presence
- ✅ Notify family members
- ✅ Track status history
- ✅ Use in complex automations

**See [homeassistant_config_example.yaml](homeassistant_config_example.yaml) for 25+ more automation examples!**
