#!/usr/bin/env python3
"""
MS Teams Presence - Complete Integrated Solution (PUSH Architecture)
Raspberry Pi + Unicorn HAT + Web Dashboard + Push Notifications + Home Assistant

Architecture: Work PC PUSHES status → Raspberry Pi receives and displays

Features:
- HTTP server receives status from work PC (POST /status)
- Unicorn HAT 8x8 LED display with animations
- Mobile-friendly web dashboard (Flask on port 5000)
- Push notifications via ntfy.sh
- Home Assistant MQTT integration
- Status history and metrics
"""

import unicornhat as unicorn
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import signal
import sys
from colorsys import hsv_to_rgb
import math
import threading
import time
from datetime import datetime
from flask import Flask, jsonify, render_template_string, request
from flask_cors import CORS
import paho.mqtt.client as mqtt
import yaml
import os

# Load configuration
def load_config():
    """Load configuration from YAML file"""
    config_path = os.path.join(os.path.dirname(__file__), 'config_push.yaml')
    try:
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        return get_default_config()

def get_default_config():
    """Default configuration"""
    return {
        'server': {
            'port': 8080  # Receives POST from work PC
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
    "Available": (0, 255, 0),
    "Busy": (255, 0, 0),
    "Away": (255, 255, 0),
    "BeRightBack": (255, 255, 0),
    "DoNotDisturb": (128, 0, 128),
    "InAMeeting": (255, 0, 0),
    "InACall": (255, 0, 0),
    "Offline": (128, 128, 128),
    "Unknown": (255, 255, 255),
}

# Status emoji mapping
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
animation_thread = None
mqtt_client = None
httpd = None

# Flask web server
app = Flask(__name__)
CORS(app)

# Import status update notifications
import requests as http_requests

# ============================================================================
# UNICORN HAT FUNCTIONS
# ============================================================================

def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    global shutdown_flag, httpd
    print("\n\n  Shutting down...")
    shutdown_flag = True
    if mqtt_client:
        mqtt_client.disconnect()
    if httpd:
        httpd.shutdown()
    clear_display()
    sys.exit(0)

def setup_unicorn():
    """Initialize Unicorn HAT"""
    unicorn.set_layout(unicorn.HAT)
    unicorn.rotation(0)
    unicorn.brightness(CONFIG['unicorn']['brightness'])

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
    """Pulse animation"""
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
    """Vertical gradient"""
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
    """Ripple effect"""
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
    """Spinning line"""
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

def animation_loop():
    """Background animation thread"""
    while not shutdown_flag:
        status = current_status['availability']
        color = STATUS_COLORS.get(status, STATUS_COLORS["Unknown"])
        animation_mode = CONFIG['unicorn']['animation_mode']

        if animation_mode == "solid":
            set_solid_color(color)
            time.sleep(0.1)
        elif animation_mode == "pulse":
            pulse_animation(color, duration=2.0)
        elif animation_mode == "gradient":
            gradient_animation(color)
            time.sleep(0.5)
        elif animation_mode == "ripple":
            ripple_animation(color, duration=1.5)
        elif animation_mode == "spinner":
            spinner_animation(color, duration=1.5)
        else:
            set_solid_color(color)
            time.sleep(0.1)

def startup_animation():
    """Rainbow startup"""
    for hue in range(360):
        if shutdown_flag:
            break
        r, g, b = [int(c * 255) for c in hsv_to_rgb(hue / 360.0, 1.0, 1.0)]
        set_solid_color((r, g, b))
        time.sleep(0.005)
    clear_display()
    time.sleep(0.5)

# ============================================================================
# WEB DASHBOARD (same as before)
# ============================================================================

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Teams Presence</title>
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
        .container { max-width: 500px; margin: 0 auto; width: 100%; }
        .card {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }
        h1 { font-size: 28px; margin-bottom: 10px; text-align: center; }
        .status-display {
            text-align: center;
            padding: 40px 20px;
            border-radius: 15px;
            margin: 20px 0;
        }
        .status-emoji { font-size: 80px; margin-bottom: 15px; }
        .status-text { font-size: 32px; font-weight: bold; margin-bottom: 10px; }
        .available { background: rgba(40, 167, 69, 0.3); }
        .busy { background: rgba(220, 53, 69, 0.3); }
        .away { background: rgba(255, 193, 7, 0.3); }
        .offline { background: rgba(108, 117, 125, 0.3); }
        .stats-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-top: 20px; }
        .stat-item { text-align: center; padding: 20px; background: rgba(255, 255, 255, 0.1); border-radius: 12px; }
        .stat-value { font-size: 28px; font-weight: bold; margin-bottom: 5px; }
    </style>
    <script>
        function updateStatus() {
            fetch('/api/status')
                .then(r => r.json())
                .then(data => {
                    document.getElementById('status-emoji').textContent = data.emoji;
                    document.getElementById('status-text').textContent = data.availability;
                    document.getElementById('status-card').className = 'status-display ' + data.availability.toLowerCase().replace(' ', '');
                    document.getElementById('uptime').textContent = data.uptime;
                });
        }
        setInterval(updateStatus, 3000);
        updateStatus();
    </script>
</head>
<body>
    <div class="container">
        <div class="card">
            <h1>📊 Teams Presence</h1>
            <div id="status-card" class="status-display {{ status_class }}">
                <div id="status-emoji" class="status-emoji">{{ emoji }}</div>
                <div id="status-text" class="status-text">{{ status }}</div>
            </div>
            <div class="stats-grid">
                <div class="stat-item">
                    <div id="uptime" class="stat-value">{{ uptime }}</div>
                    <div style="font-size: 12px; opacity: 0.8;">UPTIME</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">{{ changes }}</div>
                    <div style="font-size: 12px; opacity: 0.8;">CHANGES</div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def index():
    status = current_status['availability']
    return render_template_string(
        HTML_TEMPLATE,
        status=status,
        status_class=status.lower().replace(' ', ''),
        emoji=STATUS_EMOJI.get(status, '⚪'),
        uptime=format_uptime(current_status['uptime_seconds']),
        changes=len(status_history)
    )

@app.route('/api/status')
def api_status():
    return jsonify({
        'availability': current_status['availability'],
        'timestamp': current_status['timestamp'],
        'uptime': format_uptime(current_status['uptime_seconds']),
        'emoji': STATUS_EMOJI.get(current_status['availability'], '⚪'),
        'color': rgb_to_hex(STATUS_COLORS.get(current_status['availability'], (255, 255, 255)))
    })

def format_uptime(seconds):
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    return f"{hours}h {minutes}m" if hours > 0 else f"{minutes}m"

def rgb_to_hex(rgb):
    return '#{:02x}{:02x}{:02x}'.format(*rgb)

def run_flask():
    if CONFIG['web']['enabled']:
        # Suppress Flask's default startup messages
        import logging
        log = logging.getLogger('werkzeug')
        log.setLevel(logging.ERROR)
        app.run(host=CONFIG['web']['host'], port=CONFIG['web']['port'], debug=False, use_reloader=False)

# ============================================================================
# PUSH NOTIFICATIONS
# ============================================================================

def send_notification(status, previous_status):
    if not CONFIG['notifications']['enabled']:
        return
    if CONFIG['notifications']['only_on_change'] and status == previous_status:
        return

    try:
        emoji = STATUS_EMOJI.get(status, '⚪')
        message = f"{emoji} Your Teams status is now: {status}"
        ntfy_url = f"{CONFIG['notifications']['ntfy_server']}/{CONFIG['notifications']['ntfy_topic']}"

        http_requests.post(
            ntfy_url,
            data=message.encode('utf-8'),
            headers={"Title": "Teams Status Changed", "Priority": "default", "Tags": "computer,teams"},
            timeout=5
        )
        pass  # Notification sent silently
    except Exception:
        pass  # Silently ignore notification failures

# ============================================================================
# HOME ASSISTANT MQTT
# ============================================================================

def setup_mqtt():
    global mqtt_client
    if not CONFIG['homeassistant']['enabled']:
        return None

    mqtt_client = mqtt.Client()
    if CONFIG['homeassistant']['mqtt_username']:
        mqtt_client.username_pw_set(
            CONFIG['homeassistant']['mqtt_username'],
            CONFIG['homeassistant']['mqtt_password']
        )

    mqtt_client.on_connect = on_mqtt_connect
    try:
        mqtt_client.connect(CONFIG['homeassistant']['mqtt_broker'], CONFIG['homeassistant']['mqtt_port'], 60)
        mqtt_client.loop_start()
        return mqtt_client
    except Exception:
        return None

def on_mqtt_connect(client, userdata, flags, rc):
    if rc == 0:
        publish_ha_discovery()

def publish_ha_discovery():
    if not mqtt_client:
        return
    discovery_topic = f"{CONFIG['homeassistant']['discovery_prefix']}/sensor/teams_presence/config"
    payload = {
        "name": "Teams Presence Status",
        "unique_id": "teams_presence_status",
        "state_topic": f"{CONFIG['homeassistant']['mqtt_topic']}/state",
        "json_attributes_topic": f"{CONFIG['homeassistant']['mqtt_topic']}/attributes",
        "icon": "mdi:microsoft-teams"
    }
    mqtt_client.publish(discovery_topic, json.dumps(payload), retain=True)

def publish_mqtt_status(status):
    if not mqtt_client:
        return
    try:
        mqtt_client.publish(f"{CONFIG['homeassistant']['mqtt_topic']}/state", status, retain=True)
        attributes = {
            "emoji": STATUS_EMOJI.get(status, '⚪'),
            "color": rgb_to_hex(STATUS_COLORS.get(status, (255, 255, 255))),
            "uptime": format_uptime(current_status['uptime_seconds'])
        }
        mqtt_client.publish(f"{CONFIG['homeassistant']['mqtt_topic']}/attributes", json.dumps(attributes), retain=True)
    except Exception:
        pass  # Silently ignore MQTT publish failures

# ============================================================================
# HTTP SERVER (RECEIVES STATUS FROM WORK PC)
# ============================================================================

class TeamsStatusHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress default HTTP logging - we handle status changes ourselves
        pass

    def do_POST(self):
        """Receive status update from work PC"""
        if self.path == "/status":
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode('utf-8'))

                new_status = data.get("availability", "Unknown")
                previous_status = current_status['availability']

                if new_status != previous_status:
                    emoji = STATUS_EMOJI.get(new_status, '⚪')
                    timestamp = datetime.now().strftime("%H:%M:%S")
                    print(f"\n  {timestamp}  {emoji}  Status: {new_status}")
                    current_status['availability'] = new_status
                    current_status['timestamp'] = datetime.now().isoformat()
                    current_status['last_change'] = datetime.now().isoformat()

                    status_history.append({'status': new_status, 'timestamp': current_status['timestamp']})
                    if len(status_history) > MAX_HISTORY:
                        status_history.pop(0)

                    send_notification(new_status, previous_status)
                    publish_mqtt_status(new_status)

                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"status": "ok"}).encode('utf-8'))
            except Exception:
                self.send_response(400)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        """Status check endpoint"""
        if self.path == "/":
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            html = f"""<html><body>
                <h1>Teams Status Server (PUSH)</h1>
                <p>Current: <strong>{current_status['availability']}</strong></p>
                <p>Dashboard: <a href="http://localhost:5000">http://raspberry-pi-ip:5000</a></p>
            </body></html>"""
            self.wfile.write(html.encode('utf-8'))
        elif self.path == "/status":
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(current_status).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

# ============================================================================
# MAIN
# ============================================================================

def main():
    global animation_thread, httpd

    signal.signal(signal.SIGINT, signal_handler)

    # Clear screen and show banner
    print("\033c", end="")  # Clear terminal
    print()
    print("  ╔══════════════════════════════════════════════════════════════════╗")
    print("  ║           MS Teams Presence Server (Raspberry Pi)                ║")
    print("  ╚══════════════════════════════════════════════════════════════════╝")
    print()
    print("  ┌─────────────────────────────────────────────────────────────────┐")
    print("  │  Configuration                                                  │")
    print("  ├─────────────────────────────────────────────────────────────────┤")
    port_str = str(CONFIG['server']['port']).ljust(10)
    web_status = "Enabled" if CONFIG['web']['enabled'] else "Disabled"
    web_str = f":{CONFIG['web']['port']}" if CONFIG['web']['enabled'] else ""
    print(f"  │  Status Server Port: {port_str}  Web Dashboard: {web_status}{web_str.ljust(12)}│")
    notif_status = "Enabled" if CONFIG['notifications']['enabled'] else "Disabled"
    ha_status = "Enabled" if CONFIG['homeassistant']['enabled'] else "Disabled"
    print(f"  │  Notifications: {notif_status.ljust(12)}  Home Assistant: {ha_status.ljust(12)}│")
    print("  └─────────────────────────────────────────────────────────────────┘")
    print()

    setup_unicorn()
    startup_animation()

    # Start animation thread
    animation_thread = threading.Thread(target=animation_loop, daemon=True)
    animation_thread.start()

    # Start web dashboard
    if CONFIG['web']['enabled']:
        web_thread = threading.Thread(target=run_flask, daemon=True)
        web_thread.start()
        time.sleep(2)

    # Setup Home Assistant
    if CONFIG['homeassistant']['enabled']:
        setup_mqtt()

    # Start HTTP server
    server_address = ('', CONFIG['server']['port'])
    httpd = HTTPServer(server_address, TeamsStatusHandler)

    print("  ─────────────────────────────────────────────────────────────────")
    print("  ✓ Server ready! Waiting for status updates...")
    print("  Press Ctrl+C to stop")
    print("  ─────────────────────────────────────────────────────────────────")
    print()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.shutdown()
        clear_display()

if __name__ == "__main__":
    main()
