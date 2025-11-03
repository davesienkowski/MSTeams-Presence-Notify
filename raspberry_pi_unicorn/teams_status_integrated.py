#!/usr/bin/env python3
"""
MS Teams Presence Notification - Complete Integrated Solution
Raspberry Pi + Unicorn HAT + Web Dashboard + Push Notifications + Home Assistant

Features:
- Unicorn HAT 8x8 LED display with animations
- Mobile-friendly web dashboard (Flask)
- Push notifications via ntfy.sh
- Home Assistant MQTT integration
- Status history and metrics
"""

import unicornhat as unicorn
import requests
import time
import signal
import sys
from colorsys import hsv_to_rgb
import math
import json
from datetime import datetime
from threading import Thread
from flask import Flask, jsonify, render_template_string, request
from flask_cors import CORS
import paho.mqtt.client as mqtt
import yaml
import os

# Load configuration
def load_config():
    """Load configuration from YAML file"""
    config_path = os.path.join(os.path.dirname(__file__), 'config.yaml')
    try:
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        print("Warning: config.yaml not found, using defaults")
        return get_default_config()

def get_default_config():
    """Default configuration"""
    return {
        'server': {
            'url': 'http://YOUR_PC_IP:8080/status',
            'poll_interval': 5
        },
        'unicorn': {
            'brightness': 0.5,
            'animation_mode': 'pulse'
        },
        'web': {
            'enabled': True,
            'port': 5000,
            'host': '0.0.0.0'
        },
        'notifications': {
            'enabled': True,
            'ntfy_topic': 'myteamspresence',
            'ntfy_server': 'https://ntfy.sh',
            'only_on_change': True
        },
        'homeassistant': {
            'enabled': False,
            'mqtt_broker': 'homeassistant.local',
            'mqtt_port': 1883,
            'mqtt_username': '',
            'mqtt_password': '',
            'mqtt_topic': 'homeassistant/sensor/teams_presence',
            'discovery_prefix': 'homeassistant'
        }
    }

# Global configuration
CONFIG = load_config()

# Teams status color mapping (RGB values)
STATUS_COLORS = {
    "Available": (0, 255, 0),      # Green
    "Busy": (255, 0, 0),            # Red
    "Away": (255, 255, 0),          # Yellow
    "BeRightBack": (255, 255, 0),   # Yellow
    "DoNotDisturb": (128, 0, 128),  # Purple
    "InAMeeting": (255, 0, 0),      # Red
    "InACall": (255, 0, 0),         # Red
    "Offline": (128, 128, 128),     # Gray
    "Unknown": (255, 255, 255),     # White
}

# Status emoji mapping for notifications
STATUS_EMOJI = {
    "Available": "🟢",
    "Busy": "🔴",
    "Away": "🟡",
    "BeRightBack": "🟡",
    "DoNotDisturb": "🟣",
    "InAMeeting": "🔴",
    "InACall": "🔴",
    "Offline": "⚫",
    "Unknown": "⚪",
}

# Global state
current_status = {
    'availability': 'Unknown',
    'timestamp': datetime.now().isoformat(),
    'last_change': datetime.now().isoformat(),
    'uptime_seconds': 0
}
status_history = []
MAX_HISTORY = 100
shutdown_flag = False
mqtt_client = None

# Flask web server
app = Flask(__name__)
CORS(app)

# ============================================================================
# UNICORN HAT FUNCTIONS (From original implementation)
# ============================================================================

def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    global shutdown_flag
    print("\n\nShutting down...")
    shutdown_flag = True
    if mqtt_client:
        mqtt_client.disconnect()
    clear_display()
    sys.exit(0)

def setup_unicorn():
    """Initialize Unicorn HAT"""
    unicorn.set_layout(unicorn.HAT)
    unicorn.rotation(0)
    unicorn.brightness(CONFIG['unicorn']['brightness'])
    print(f"Unicorn HAT initialized: 8x8 matrix at {int(CONFIG['unicorn']['brightness'] * 100)}% brightness")

def clear_display():
    """Clear all LEDs"""
    unicorn.clear()
    unicorn.show()

def set_solid_color(color):
    """Fill entire matrix with solid color"""
    r, g, b = color
    for x in range(8):
        for y in range(8):
            unicorn.set_pixel(x, y, r, g, b)
    unicorn.show()

def pulse_animation(color, duration=2.0, steps=50):
    """Pulse animation - brightness fade in/out"""
    r, g, b = color
    for i in range(steps):
        if shutdown_flag:
            break
        brightness = (math.sin(i * math.pi * 2 / steps) + 1) / 2
        scaled_r = int(r * brightness)
        scaled_g = int(g * brightness)
        scaled_b = int(b * brightness)
        for x in range(8):
            for y in range(8):
                unicorn.set_pixel(x, y, scaled_r, scaled_g, scaled_b)
        unicorn.show()
        time.sleep(duration / steps)

def gradient_animation(color):
    """Vertical gradient from color to black"""
    r, g, b = color
    for y in range(8):
        intensity = (7 - y) / 7
        scaled_r = int(r * intensity)
        scaled_g = int(g * intensity)
        scaled_b = int(b * intensity)
        for x in range(8):
            unicorn.set_pixel(x, y, scaled_r, scaled_g, scaled_b)
    unicorn.show()

def ripple_animation(color, duration=1.0):
    """Ripple effect from center"""
    r, g, b = color
    center_x, center_y = 3.5, 3.5
    max_distance = math.sqrt(center_x**2 + center_y**2)
    steps = 20
    for step in range(steps):
        if shutdown_flag:
            break
        for x in range(8):
            for y in range(8):
                distance = math.sqrt((x - center_x)**2 + (y - center_y)**2)
                wave_position = (step / steps) * max_distance
                intensity = 1.0 - abs(distance - wave_position) / max_distance
                intensity = max(0, min(1, intensity))
                scaled_r = int(r * intensity)
                scaled_g = int(g * intensity)
                scaled_b = int(b * intensity)
                unicorn.set_pixel(x, y, scaled_r, scaled_g, scaled_b)
        unicorn.show()
        time.sleep(duration / steps)

def spinner_animation(color, duration=1.0):
    """Spinning line animation"""
    r, g, b = color
    center_x, center_y = 3.5, 3.5
    steps = 24
    for step in range(steps):
        if shutdown_flag:
            break
        unicorn.clear()
        angle = (step / steps) * 2 * math.pi
        for radius in range(5):
            x = int(center_x + radius * math.cos(angle))
            y = int(center_y + radius * math.sin(angle))
            if 0 <= x < 8 and 0 <= y < 8:
                intensity = 1.0 - (radius / 5)
                unicorn.set_pixel(x, y, int(r * intensity), int(g * intensity), int(b * intensity))
        unicorn.show()
        time.sleep(duration / steps)

def display_status(status):
    """Display status with selected animation"""
    color = STATUS_COLORS.get(status, STATUS_COLORS["Unknown"])
    animation_mode = CONFIG['unicorn']['animation_mode']

    if animation_mode == "solid":
        set_solid_color(color)
    elif animation_mode == "pulse":
        pulse_animation(color, duration=2.0)
    elif animation_mode == "gradient":
        gradient_animation(color)
    elif animation_mode == "ripple":
        ripple_animation(color, duration=1.5)
    elif animation_mode == "spinner":
        spinner_animation(color, duration=1.5)
    else:
        set_solid_color(color)

def startup_animation():
    """Rainbow animation on startup"""
    print("Running startup animation...")
    for hue in range(360):
        if shutdown_flag:
            break
        r, g, b = [int(c * 255) for c in hsv_to_rgb(hue / 360.0, 1.0, 1.0)]
        set_solid_color((r, g, b))
        time.sleep(0.005)
    clear_display()
    time.sleep(0.5)

# ============================================================================
# WEB DASHBOARD
# ============================================================================

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <title>Teams Presence Monitor</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            color: #fff;
            padding: 20px;
        }
        .container {
            max-width: 500px;
            margin: 0 auto;
            width: 100%;
        }
        .card {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
            border: 1px solid rgba(255, 255, 255, 0.18);
        }
        h1 {
            font-size: 28px;
            margin-bottom: 10px;
            text-align: center;
        }
        .subtitle {
            text-align: center;
            opacity: 0.8;
            font-size: 14px;
            margin-bottom: 30px;
        }
        .status-display {
            text-align: center;
            padding: 40px 20px;
            border-radius: 15px;
            margin: 20px 0;
            transition: all 0.3s ease;
        }
        .status-emoji {
            font-size: 80px;
            margin-bottom: 15px;
            animation: pulse 2s ease-in-out infinite;
        }
        .status-text {
            font-size: 32px;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .status-time {
            font-size: 14px;
            opacity: 0.8;
        }
        .available { background: rgba(40, 167, 69, 0.3); }
        .busy { background: rgba(220, 53, 69, 0.3); }
        .away { background: rgba(255, 193, 7, 0.3); }
        .offline { background: rgba(108, 117, 125, 0.3); }
        .unknown { background: rgba(255, 255, 255, 0.2); }
        .stats-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
            margin-top: 20px;
        }
        .stat-item {
            text-align: center;
            padding: 20px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 12px;
        }
        .stat-value {
            font-size: 28px;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .stat-label {
            font-size: 12px;
            opacity: 0.8;
            text-transform: uppercase;
        }
        .history {
            max-height: 200px;
            overflow-y: auto;
            margin-top: 15px;
        }
        .history-item {
            padding: 10px;
            background: rgba(255, 255, 255, 0.05);
            border-radius: 8px;
            margin-bottom: 8px;
            font-size: 14px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .refresh-notice {
            text-align: center;
            font-size: 12px;
            opacity: 0.6;
            margin-top: 10px;
        }
        @keyframes pulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.1); }
        }
        .footer {
            text-align: center;
            margin-top: auto;
            padding-top: 20px;
            font-size: 12px;
            opacity: 0.6;
        }
    </style>
    <script>
        function updateStatus() {
            fetch('/api/status')
                .then(response => response.json())
                .then(data => {
                    // Update status display
                    const statusEmoji = document.getElementById('status-emoji');
                    const statusText = document.getElementById('status-text');
                    const statusTime = document.getElementById('status-time');
                    const statusCard = document.getElementById('status-card');

                    statusEmoji.textContent = data.emoji;
                    statusText.textContent = data.availability;
                    statusTime.textContent = 'Updated: ' + new Date(data.timestamp).toLocaleTimeString();

                    // Update card background color
                    statusCard.className = 'status-display ' + data.availability.toLowerCase().replace(' ', '');

                    // Update stats
                    document.getElementById('uptime').textContent = data.uptime;
                    document.getElementById('changes').textContent = data.change_count || '0';
                })
                .catch(error => console.error('Error fetching status:', error));
        }

        // Update every 3 seconds
        setInterval(updateStatus, 3000);

        // Initial update
        updateStatus();
    </script>
</head>
<body>
    <div class="container">
        <div class="card">
            <h1>📊 Teams Presence</h1>
            <div class="subtitle">Real-time status monitor</div>

            <div id="status-card" class="status-display {{ status_class }}">
                <div id="status-emoji" class="status-emoji">{{ emoji }}</div>
                <div id="status-text" class="status-text">{{ status }}</div>
                <div id="status-time" class="status-time">Updated: {{ last_update }}</div>
            </div>

            <div class="stats-grid">
                <div class="stat-item">
                    <div id="uptime" class="stat-value">{{ uptime }}</div>
                    <div class="stat-label">Uptime</div>
                </div>
                <div class="stat-item">
                    <div id="changes" class="stat-value">{{ changes }}</div>
                    <div class="stat-label">Changes Today</div>
                </div>
            </div>

            <div class="refresh-notice">
                ⟳ Auto-refreshing every 3 seconds
            </div>
        </div>

        {% if history %}
        <div class="card">
            <h2 style="font-size: 20px; margin-bottom: 15px;">📜 Recent History</h2>
            <div class="history">
                {% for item in history %}
                <div class="history-item">
                    <span>{{ item.emoji }} {{ item.status }}</span>
                    <span style="opacity: 0.6;">{{ item.time }}</span>
                </div>
                {% endfor %}
            </div>
        </div>
        {% endif %}
    </div>

    <div class="footer">
        Teams Presence Monitor v2.0<br>
        Raspberry Pi + Unicorn HAT
    </div>
</body>
</html>
"""

@app.route('/')
def index():
    """Main dashboard page"""
    uptime = format_uptime(current_status['uptime_seconds'])
    last_update = datetime.fromisoformat(current_status['timestamp']).strftime('%H:%M:%S')

    status = current_status['availability']
    status_class = status.lower().replace(' ', '')

    # Get recent history
    recent_history = []
    for item in status_history[-10:]:
        recent_history.append({
            'emoji': STATUS_EMOJI.get(item['status'], '⚪'),
            'status': item['status'],
            'time': datetime.fromisoformat(item['timestamp']).strftime('%H:%M:%S')
        })
    recent_history.reverse()

    return render_template_string(
        HTML_TEMPLATE,
        status=status,
        status_class=status_class,
        emoji=STATUS_EMOJI.get(status, '⚪'),
        last_update=last_update,
        uptime=uptime,
        changes=len(status_history),
        history=recent_history
    )

@app.route('/api/status')
def api_status():
    """JSON API endpoint"""
    return jsonify({
        'availability': current_status['availability'],
        'timestamp': current_status['timestamp'],
        'last_change': current_status['last_change'],
        'uptime': format_uptime(current_status['uptime_seconds']),
        'uptime_seconds': current_status['uptime_seconds'],
        'emoji': STATUS_EMOJI.get(current_status['availability'], '⚪'),
        'color': rgb_to_hex(STATUS_COLORS.get(current_status['availability'], (255, 255, 255))),
        'change_count': len(status_history)
    })

@app.route('/api/history')
def api_history():
    """Status history API endpoint"""
    return jsonify({
        'history': status_history[-50:],
        'count': len(status_history)
    })

@app.route('/api/config', methods=['GET', 'POST'])
def api_config():
    """Configuration API endpoint"""
    if request.method == 'POST':
        # Update configuration (requires authentication in production)
        data = request.json
        # TODO: Implement configuration updates
        return jsonify({'status': 'success', 'message': 'Configuration update not yet implemented'})
    else:
        return jsonify({
            'animation_mode': CONFIG['unicorn']['animation_mode'],
            'brightness': CONFIG['unicorn']['brightness'],
            'poll_interval': CONFIG['server']['poll_interval']
        })

def format_uptime(seconds):
    """Format uptime in human-readable format"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    if hours > 0:
        return f"{hours}h {minutes}m"
    else:
        return f"{minutes}m"

def rgb_to_hex(rgb):
    """Convert RGB tuple to hex color string"""
    return '#{:02x}{:02x}{:02x}'.format(*rgb)

def run_flask():
    """Run Flask web server in background thread"""
    if CONFIG['web']['enabled']:
        print(f"Starting web server on http://{CONFIG['web']['host']}:{CONFIG['web']['port']}")
        app.run(
            host=CONFIG['web']['host'],
            port=CONFIG['web']['port'],
            debug=False,
            use_reloader=False
        )

# ============================================================================
# PUSH NOTIFICATIONS
# ============================================================================

def send_notification(status, previous_status):
    """Send push notification via ntfy.sh"""
    if not CONFIG['notifications']['enabled']:
        return

    if CONFIG['notifications']['only_on_change'] and status == previous_status:
        return

    try:
        emoji = STATUS_EMOJI.get(status, '⚪')
        title = "Teams Status Changed"
        message = f"{emoji} Your Teams status is now: {status}"

        ntfy_url = f"{CONFIG['notifications']['ntfy_server']}/{CONFIG['notifications']['ntfy_topic']}"

        requests.post(
            ntfy_url,
            data=message.encode('utf-8'),
            headers={
                "Title": title,
                "Priority": "default",
                "Tags": "computer,teams,microsoft"
            },
            timeout=5
        )
        print(f"✓ Push notification sent: {status}")
    except Exception as e:
        print(f"✗ Failed to send notification: {e}")

# ============================================================================
# HOME ASSISTANT MQTT INTEGRATION
# ============================================================================

def setup_mqtt():
    """Initialize MQTT client for Home Assistant"""
    global mqtt_client

    if not CONFIG['homeassistant']['enabled']:
        return None

    mqtt_client = mqtt.Client()

    # Set credentials if provided
    if CONFIG['homeassistant']['mqtt_username']:
        mqtt_client.username_pw_set(
            CONFIG['homeassistant']['mqtt_username'],
            CONFIG['homeassistant']['mqtt_password']
        )

    # Connect callbacks
    mqtt_client.on_connect = on_mqtt_connect
    mqtt_client.on_disconnect = on_mqtt_disconnect

    try:
        mqtt_client.connect(
            CONFIG['homeassistant']['mqtt_broker'],
            CONFIG['homeassistant']['mqtt_port'],
            60
        )
        mqtt_client.loop_start()
        print(f"✓ Connected to MQTT broker: {CONFIG['homeassistant']['mqtt_broker']}")
        return mqtt_client
    except Exception as e:
        print(f"✗ Failed to connect to MQTT broker: {e}")
        return None

def on_mqtt_connect(client, userdata, flags, rc):
    """MQTT connection callback"""
    if rc == 0:
        print("✓ MQTT connected successfully")
        publish_ha_discovery()
    else:
        print(f"✗ MQTT connection failed with code {rc}")

def on_mqtt_disconnect(client, userdata, rc):
    """MQTT disconnection callback"""
    if rc != 0:
        print("✗ Unexpected MQTT disconnection, attempting to reconnect...")

def publish_ha_discovery():
    """Publish Home Assistant MQTT discovery configuration"""
    if not mqtt_client:
        return

    discovery_prefix = CONFIG['homeassistant']['discovery_prefix']
    device_name = "teams_presence"

    # Main sensor discovery
    discovery_topic = f"{discovery_prefix}/sensor/{device_name}/config"
    discovery_payload = {
        "name": "Teams Presence Status",
        "unique_id": f"{device_name}_status",
        "state_topic": f"{CONFIG['homeassistant']['mqtt_topic']}/state",
        "json_attributes_topic": f"{CONFIG['homeassistant']['mqtt_topic']}/attributes",
        "icon": "mdi:microsoft-teams",
        "device": {
            "identifiers": [device_name],
            "name": "MS Teams Presence",
            "model": "Raspberry Pi + Unicorn HAT",
            "manufacturer": "Custom",
            "sw_version": "2.0"
        }
    }

    mqtt_client.publish(discovery_topic, json.dumps(discovery_payload), retain=True)
    print("✓ Published Home Assistant discovery configuration")

def publish_mqtt_status(status):
    """Publish status update to Home Assistant via MQTT"""
    if not mqtt_client:
        return

    try:
        # Publish state
        state_topic = f"{CONFIG['homeassistant']['mqtt_topic']}/state"
        mqtt_client.publish(state_topic, status, retain=True)

        # Publish attributes
        attributes_topic = f"{CONFIG['homeassistant']['mqtt_topic']}/attributes"
        attributes = {
            "status": status,
            "emoji": STATUS_EMOJI.get(status, '⚪'),
            "color": rgb_to_hex(STATUS_COLORS.get(status, (255, 255, 255))),
            "last_update": datetime.now().isoformat(),
            "uptime": format_uptime(current_status['uptime_seconds'])
        }
        mqtt_client.publish(attributes_topic, json.dumps(attributes), retain=True)

        print(f"✓ Published to Home Assistant: {status}")
    except Exception as e:
        print(f"✗ Failed to publish MQTT status: {e}")

# ============================================================================
# MAIN MONITORING LOOP
# ============================================================================

def get_teams_status():
    """Fetch current Teams status from PowerShell server"""
    try:
        response = requests.get(CONFIG['server']['url'], timeout=3)
        if response.status_code == 200:
            data = response.json()
            return data.get("availability", "Unknown")
        else:
            print(f"HTTP Error: {response.status_code}")
            return "Unknown"
    except requests.exceptions.Timeout:
        print("Request timeout - server not responding")
        return None
    except requests.exceptions.ConnectionError:
        print("Connection error - check server URL and network")
        return None
    except Exception as e:
        print(f"Error fetching status: {e}")
        return None

def update_status(new_status, previous_status):
    """Update global status and trigger integrations"""
    global current_status

    current_status['availability'] = new_status
    current_status['timestamp'] = datetime.now().isoformat()
    current_status['uptime_seconds'] += CONFIG['server']['poll_interval']

    # If status changed
    if new_status != previous_status:
        current_status['last_change'] = datetime.now().isoformat()

        # Add to history
        status_history.append({
            'status': new_status,
            'timestamp': current_status['timestamp']
        })

        # Keep history size manageable
        if len(status_history) > MAX_HISTORY:
            status_history.pop(0)

        # Trigger integrations
        send_notification(new_status, previous_status)
        publish_mqtt_status(new_status)

def main():
    """Main application loop"""
    global shutdown_flag

    # Setup signal handler
    signal.signal(signal.SIGINT, signal_handler)

    print("=" * 60)
    print("MS Teams Presence - Complete Integrated Solution")
    print("=" * 60)
    print(f"Teams Server: {CONFIG['server']['url']}")
    print(f"Poll Interval: {CONFIG['server']['poll_interval']} seconds")
    print(f"Animation Mode: {CONFIG['unicorn']['animation_mode']}")
    print(f"Brightness: {int(CONFIG['unicorn']['brightness'] * 100)}%")
    print()
    print("Integrations:")
    print(f"  Web Dashboard: {'✓ Enabled' if CONFIG['web']['enabled'] else '✗ Disabled'}")
    if CONFIG['web']['enabled']:
        print(f"    → http://{CONFIG['web']['host']}:{CONFIG['web']['port']}")
    print(f"  Push Notifications: {'✓ Enabled' if CONFIG['notifications']['enabled'] else '✗ Disabled'}")
    if CONFIG['notifications']['enabled']:
        print(f"    → ntfy.sh/{CONFIG['notifications']['ntfy_topic']}")
    print(f"  Home Assistant: {'✓ Enabled' if CONFIG['homeassistant']['enabled'] else '✗ Disabled'}")
    if CONFIG['homeassistant']['enabled']:
        print(f"    → {CONFIG['homeassistant']['mqtt_broker']}")
    print()
    print("Press Ctrl+C to exit\n")

    # Initialize hardware
    setup_unicorn()
    startup_animation()

    # Start web server in background
    if CONFIG['web']['enabled']:
        web_thread = Thread(target=run_flask, daemon=True)
        web_thread.start()
        time.sleep(2)  # Give Flask time to start

    # Setup Home Assistant MQTT
    if CONFIG['homeassistant']['enabled']:
        setup_mqtt()

    # Main monitoring loop
    previous_status = None
    connection_errors = 0
    max_connection_errors = 5

    while not shutdown_flag:
        status = get_teams_status()

        if status is None:
            connection_errors += 1
            if connection_errors >= max_connection_errors:
                print(f"Too many connection errors ({connection_errors}), showing error state...")
                set_solid_color((255, 0, 0))  # Red for error
            time.sleep(CONFIG['server']['poll_interval'])
            continue

        # Reset error counter
        connection_errors = 0

        # Update status and integrations
        update_status(status, previous_status)

        # Update display if status changed
        if status != previous_status:
            print(f"Status changed: {previous_status} → {status}")
            display_status(status)
            previous_status = status
        elif CONFIG['unicorn']['animation_mode'] != "solid":
            # Keep animating
            display_status(status)

        time.sleep(CONFIG['server']['poll_interval'])

if __name__ == "__main__":
    main()
