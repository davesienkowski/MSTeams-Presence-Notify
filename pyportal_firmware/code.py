"""
Teams Status Monitor for Adafruit PyPortal
CircuitPython implementation - CLIENT MODE

This version POLLS a PowerShell HTTP server running on your PC.
Architecture: PC (PowerShell server) ← PyPortal (HTTP client polls every 5s)

Features:
- WiFi HTTP client (using ESP32 SPI coprocessor)
- 3.2" color display showing status
- NeoPixel status indicator
- Polls PC server every 5 seconds for Teams status

Hardware: Adafruit PyPortal (any variant)
Software: CircuitPython 9.x or 10.x
Libraries: adafruit_esp32spi, adafruit_requests, adafruit_display_text, neopixel
"""

import time
import board
import busio
import displayio
import terminalio
import neopixel
from digitalio import DigitalInOut
from adafruit_display_text import label
from adafruit_esp32spi import adafruit_esp32spi
import adafruit_esp32spi.adafruit_esp32spi_socket as socket
import adafruit_requests as requests

# ==================== CONFIGURATION ====================
# WiFi credentials
WIFI_SSID = "C&D"
WIFI_PASSWORD = "sienkows1"

# PowerShell server configuration
# Replace with your PC's IP address (find with: ipconfig in Windows)
SERVER_IP = "192.168.1.100"  # ⚠️ CHANGE THIS TO YOUR PC'S IP!
SERVER_PORT = 8080
SERVER_URL = f"http://{SERVER_IP}:{SERVER_PORT}/status"

# Polling interval (seconds)
POLL_INTERVAL = 5

# ==================== STATUS DEFINITIONS ====================
# Map PowerShell status strings to colors
STATUS_MAP = {
    "Available": {"color": 0x00FF00, "bg": 0x002200, "name": "Available"},
    "Busy": {"color": 0xFF0000, "bg": 0x220000, "name": "Busy"},
    "Away": {"color": 0xFFFF00, "bg": 0x222200, "name": "Away"},
    "BeRightBack": {"color": 0xFFFF00, "bg": 0x222200, "name": "Be Right Back"},
    "DoNotDisturb": {"color": 0x800080, "bg": 0x200020, "name": "Do Not Disturb"},
    "Focusing": {"color": 0x800080, "bg": 0x200020, "name": "Focusing"},
    "Presenting": {"color": 0xFF0000, "bg": 0x220000, "name": "Presenting"},
    "InAMeeting": {"color": 0xFF0000, "bg": 0x220000, "name": "In a Meeting"},
    "InACall": {"color": 0xFF0000, "bg": 0x220000, "name": "In a Call"},
    "Offline": {"color": 0x323232, "bg": 0x101010, "name": "Offline"},
    "Unknown": {"color": 0xFFFFFF, "bg": 0x111111, "name": "Unknown"}
}

# Default status
DEFAULT_STATUS = {
    "color": 0xFFFFFF,
    "bg": 0x000000,
    "name": "Starting..."
}

# ==================== HARDWARE SETUP ====================
# NeoPixel (built-in on PyPortal)
pixel = neopixel.NeoPixel(board.NEOPIXEL, 1, brightness=0.3)
pixel.fill(0xFFFFFF)  # White on startup

# Display setup
display = board.DISPLAY
display.brightness = 0.8

# Create display group
splash = displayio.Group()
display.root_group = splash

# Background color bitmap
color_bitmap = displayio.Bitmap(320, 240, 1)
color_palette = displayio.Palette(1)
color_palette[0] = 0x000000  # Black initially
bg_sprite = displayio.TileGrid(color_bitmap, pixel_shader=color_palette, x=0, y=0)
splash.append(bg_sprite)

# Title text
title_text = label.Label(
    terminalio.FONT,
    text="Teams Status",
    color=0xFFFFFF,
    scale=2,
    x=80,
    y=20
)
splash.append(title_text)

# Status text (large)
status_text = label.Label(
    terminalio.FONT,
    text="Starting...",
    color=0xFFFFFF,
    scale=3,
    x=40,
    y=100
)
splash.append(status_text)

# Info text (small)
info_text = label.Label(
    terminalio.FONT,
    text="Connecting...",
    color=0xAAAAAA,
    scale=1,
    x=10,
    y=180
)
splash.append(info_text)

# Connection info text
conn_text = label.Label(
    terminalio.FONT,
    text="",
    color=0x00FF00,
    scale=1,
    x=10,
    y=220
)
splash.append(conn_text)

# ==================== STATE ====================
current_status = "Unknown"
last_update = 0
request_count = 0
error_count = 0

# ==================== ESP32 SPI SETUP ====================
print("\n" + "="*50)
print("Teams Status Monitor - PyPortal CLIENT")
print("="*50 + "\n")

# ESP32 SPI pins (specific to PyPortal)
esp32_cs = DigitalInOut(board.ESP_CS)
esp32_ready = DigitalInOut(board.ESP_BUSY)
esp32_reset = DigitalInOut(board.ESP_RESET)

spi = busio.SPI(board.SCK, board.MOSI, board.MISO)
esp = adafruit_esp32spi.ESP_SPIcontrol(spi, esp32_cs, esp32_ready, esp32_reset)

# Check ESP32 firmware
print(f"ESP32 Firmware: {'.'.join(map(str, esp.firmware_version))}")

# ==================== WIFI CONNECTION ====================
print(f"Connecting to WiFi: {WIFI_SSID}")
info_text.text = "Connecting to WiFi..."

try:
    esp.connect_AP(WIFI_SSID, WIFI_PASSWORD)

    print(f"✓ Connected!")
    print(f"IP Address: {'.'.join(map(str, esp.ip_address))}")

    # Update display
    ip_str = '.'.join(map(str, esp.ip_address))
    conn_text.text = f"IP: {ip_str}"
    info_text.text = "WiFi Connected!"
    pixel.fill(0x00FF00)  # Green = connected
    time.sleep(1)

except Exception as e:
    print(f"✗ WiFi connection failed: {e}")
    info_text.text = f"WiFi ERROR!"
    status_text.text = "NO WIFI"
    status_text.color = 0xFF0000
    while True:
        pixel.fill(0xFF0000)
        time.sleep(0.5)
        pixel.fill(0x000000)
        time.sleep(0.5)

# ==================== HTTP CLIENT SETUP ====================
# Create socket pool and requests session
socket.set_interface(esp)
http = requests.Session(socket)

print(f"✓ HTTP client ready")
print(f"Polling: {SERVER_URL}")
print(f"Interval: {POLL_INTERVAL} seconds\n")
print("="*50 + "\n")

# ==================== DISPLAY FUNCTIONS ====================
def update_display(status_name, timestamp=None):
    """Update display and NeoPixel for status"""
    global current_status, last_update

    current_status = status_name
    last_update = time.monotonic()

    # Get status info
    status_info = STATUS_MAP.get(status_name, DEFAULT_STATUS)

    # Update status text
    display_name = status_info["name"]
    status_text.text = display_name

    # Center the status text (approximate)
    text_width = len(display_name) * 18  # Approximate width with scale=3
    status_text.x = max(0, (320 - text_width) // 2)

    # Update colors
    status_text.color = status_info["color"]
    color_palette[0] = status_info["bg"]
    pixel.fill(status_info["color"])

    # Update info text with timestamp or request count
    if timestamp:
        info_text.text = timestamp
    else:
        info_text.text = f"Requests: {request_count} | Errors: {error_count}"

def parse_json_simple(text):
    """Simple JSON parser for our specific use case"""
    try:
        # Extract values using simple string parsing
        result = {}

        # Find "availability": "value"
        if '"availability"' in text:
            start = text.find('"availability"')
            colon = text.find(':', start)
            quote1 = text.find('"', colon)
            quote2 = text.find('"', quote1 + 1)
            result['availability'] = text[quote1+1:quote2]

        # Find "activity": "value"
        if '"activity"' in text:
            start = text.find('"activity"')
            colon = text.find(':', start)
            quote1 = text.find('"', colon)
            quote2 = text.find('"', quote1 + 1)
            result['activity'] = text[quote1+1:quote2]

        # Find "color": "value"
        if '"color"' in text:
            start = text.find('"color"')
            colon = text.find(':', start)
            quote1 = text.find('"', colon)
            quote2 = text.find('"', quote1 + 1)
            result['color'] = text[quote1+1:quote2]

        return result
    except:
        return None

def fetch_status():
    """Fetch status from PowerShell server"""
    global request_count, error_count

    try:
        request_count += 1

        # Make GET request to server
        response = http.get(SERVER_URL, timeout=5)

        if response.status_code == 200:
            # Parse JSON response
            json_data = parse_json_simple(response.text)

            if json_data and 'availability' in json_data:
                availability = json_data['availability']

                # Update display
                now = time.localtime()
                timestamp = f"Updated: {now[3]:02d}:{now[4]:02d}:{now[5]:02d}"
                update_display(availability, timestamp)

                # Log to console
                print(f"[{now[3]:02d}:{now[4]:02d}:{now[5]:02d}] Status: {availability}")

                # Reset error count on success
                if error_count > 0:
                    error_count = 0
            else:
                print("✗ Invalid JSON response")
                error_count += 1
        else:
            print(f"✗ HTTP error: {response.status_code}")
            error_count += 1

        response.close()

    except Exception as e:
        print(f"✗ Request failed: {e}")
        error_count += 1

        # Show error on display if too many failures
        if error_count >= 3:
            info_text.text = f"ERROR: Can't reach server"
            info_text.color = 0xFF0000

# ==================== INITIAL STATUS ====================
# Set initial display
update_display("Unknown")
info_text.text = "Waiting for first poll..."
conn_text.text = f"Server: {SERVER_IP}:{SERVER_PORT}"

# Wait a moment before first poll
time.sleep(2)

# ==================== MAIN POLLING LOOP ====================
print("Starting polling loop...\n")

last_poll = 0
next_poll = 0

while True:
    try:
        current_time = time.monotonic()

        # Check if it's time to poll
        if current_time >= next_poll:
            fetch_status()
            next_poll = current_time + POLL_INTERVAL
            last_poll = current_time

        # Small delay to prevent tight loop
        time.sleep(0.1)

    except KeyboardInterrupt:
        print("\n\nShutting down...")
        break
    except Exception as e:
        print(f"✗ Main loop error: {e}")
        time.sleep(1)

# Cleanup
pixel.fill(0x000000)
print("Stopped.")
