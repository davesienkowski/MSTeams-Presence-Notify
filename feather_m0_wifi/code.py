"""
Teams Status Monitor for Adafruit Feather M0 WiFi
CircuitPython HTTP Server implementation

This version runs an HTTP SERVER that receives status updates from your Work PC.
Architecture: Work PC (HTTP client) → Feather M0 WiFi (HTTP server)

Features:
- WiFi HTTP server (using ATWINC1500 chip)
- Configurable output: NeoPixel, RGB LED, or OLED display
- Receives status via POST /status endpoint
- Simple JSON API

Hardware: Adafruit Feather M0 WiFi (ATWINC1500)
Software: CircuitPython 8.x or 9.x
Libraries: adafruit_httpserver, adafruit_esp32spi (for ATWINC1500), neopixel or displayio
"""

import time
import board
import busio
import digitalio
import supervisor

# ==================== CONFIGURATION ====================
# WiFi credentials
WIFI_SSID = "C&D"
WIFI_PASSWORD = "sienkows1"

# HTTP server configuration
HTTP_PORT = 80

# Output device configuration
# Options: "NEOPIXEL", "RGB_LED", "OLED", "LED_MATRIX"
OUTPUT_DEVICE = "LED_MATRIX"  # Set to LED_MATRIX for IS31FL3731 FeatherWing

# Pin configuration (adjust based on your wiring)
# For NeoPixel
NEOPIXEL_PIN = board.D6
NEOPIXEL_COUNT = 8

# For RGB LED (common cathode)
RGB_RED_PIN = board.D5
RGB_GREEN_PIN = board.D6
RGB_BLUE_PIN = board.D9

# For OLED (uses I2C)
# No pin config needed - uses board.SCL and board.SDA

# ==================== STATUS DEFINITIONS ====================
STATUS_NAMES = {
    0: "Available",
    1: "Busy",
    2: "Away",
    3: "Be Right Back",
    4: "Do Not Disturb",
    5: "Focusing",
    6: "Presenting",
    7: "In a Meeting",
    8: "In a Call",
    9: "Offline",
    10: "Unknown"
}

# RGB color values (0-255)
STATUS_COLORS = {
    0: (0, 255, 0),      # Green - Available
    1: (255, 0, 0),      # Red - Busy
    2: (255, 255, 0),    # Yellow - Away
    3: (255, 255, 0),    # Yellow - Be Right Back
    4: (128, 0, 128),    # Purple - Do Not Disturb
    5: (128, 0, 128),    # Purple - Focusing
    6: (255, 0, 0),      # Red - Presenting
    7: (255, 0, 0),      # Red - In a Meeting
    8: (255, 0, 0),      # Red - In a Call
    9: (50, 50, 50),     # Dim Gray - Offline
    10: (255, 255, 255)  # White - Unknown
}

# ==================== HARDWARE SETUP ====================
print("\n" + "="*50)
print("Teams Status Monitor - Feather M0 WiFi SERVER")
print("="*50 + "\n")

# Initialize output device
output_device = None

if OUTPUT_DEVICE == "NEOPIXEL":
    try:
        import neopixel
        output_device = neopixel.NeoPixel(NEOPIXEL_PIN, NEOPIXEL_COUNT, brightness=0.3, auto_write=False)
        output_device.fill((255, 255, 255))  # White on startup
        output_device.show()
        print(f"✓ NeoPixel initialized ({NEOPIXEL_COUNT} pixels)")
    except Exception as e:
        print(f"✗ NeoPixel init failed: {e}")
        OUTPUT_DEVICE = None

elif OUTPUT_DEVICE == "RGB_LED":
    try:
        import pwmio
        red_led = pwmio.PWMOut(RGB_RED_PIN, frequency=1000, duty_cycle=0)
        green_led = pwmio.PWMOut(RGB_GREEN_PIN, frequency=1000, duty_cycle=0)
        blue_led = pwmio.PWMOut(RGB_BLUE_PIN, frequency=1000, duty_cycle=0)
        output_device = {"red": red_led, "green": green_led, "blue": blue_led}
        print("✓ RGB LED initialized")
    except Exception as e:
        print(f"✗ RGB LED init failed: {e}")
        OUTPUT_DEVICE = None

elif OUTPUT_DEVICE == "OLED":
    try:
        import displayio
        import terminalio
        from adafruit_display_text import label
        import adafruit_displayio_ssd1306

        displayio.release_displays()
        i2c = busio.I2C(board.SCL, board.SDA)
        display_bus = displayio.I2CDisplay(i2c, device_address=0x3C)
        display = adafruit_displayio_ssd1306.SSD1306(display_bus, width=128, height=32)

        splash = displayio.Group()
        display.root_group = splash

        title_text = label.Label(terminalio.FONT, text="Teams Status", color=0xFFFFFF, x=0, y=4)
        status_text = label.Label(terminalio.FONT, text="Starting...", color=0xFFFFFF, x=0, y=20)
        splash.append(title_text)
        splash.append(status_text)

        output_device = {"display": display, "status_text": status_text}
        print("✓ OLED display initialized")
    except Exception as e:
        print(f"✗ OLED init failed: {e}")
        OUTPUT_DEVICE = None

elif OUTPUT_DEVICE == "LED_MATRIX":
    try:
        from adafruit_is31fl3731.charlie_wing import CharlieWing

        i2c = busio.I2C(board.SCL, board.SDA)
        matrix = CharlieWing(i2c)
        matrix.fill(0)  # Clear matrix

        # Create status icons/patterns (15x7 matrix)
        # Simple color bars showing status
        output_device = {"matrix": matrix, "width": 15, "height": 7}
        print("✓ IS31FL3731 LED Matrix initialized (15x7)")
    except Exception as e:
        print(f"✗ LED Matrix init failed: {e}")
        OUTPUT_DEVICE = None

# ==================== WiFi SETUP (ATWINC1500) ====================
print(f"Connecting to WiFi: {WIFI_SSID}")

try:
    # Import WiFi libraries for ATWINC1500
    from adafruit_esp32spi import adafruit_esp32spi
    import adafruit_esp32spi.adafruit_esp32spi_socket as socket

    # ATWINC1500 uses SPI
    esp32_cs = digitalio.DigitalInOut(board.D13)
    esp32_ready = digitalio.DigitalInOut(board.D11)
    esp32_reset = digitalio.DigitalInOut(board.D12)

    spi = busio.SPI(board.SCK, board.MOSI, board.MISO)
    esp = adafruit_esp32spi.ESP_SPIcontrol(spi, esp32_cs, esp32_ready, esp32_reset)

    print(f"WiFi Firmware: {'.'.join(map(str, esp.firmware_version))}")

    # Connect to WiFi
    esp.connect_AP(WIFI_SSID, WIFI_PASSWORD)

    print(f"✓ Connected!")
    print(f"IP Address: {'.'.join(map(str, esp.ip_address))}")
    ip_str = '.'.join(map(str, esp.ip_address))

    # Set socket interface
    socket.set_interface(esp)

except Exception as e:
    print(f"✗ WiFi connection failed: {e}")
    print("\nPlease check:")
    print("1. WiFi credentials in code.py")
    print("2. 2.4GHz network (ATWINC1500 doesn't support 5GHz)")
    print("3. Signal strength")
    while True:
        if output_device and OUTPUT_DEVICE == "NEOPIXEL":
            output_device.fill((255, 0, 0))
            output_device.show()
            time.sleep(0.5)
            output_device.fill((0, 0, 0))
            output_device.show()
            time.sleep(0.5)
        else:
            time.sleep(1)

# ==================== HTTP SERVER SETUP ====================
try:
    from adafruit_httpserver import Server, Request, Response, POST

    server = Server(socket, "/static", debug=False)

    print(f"✓ HTTP server ready on port {HTTP_PORT}")
    print(f"\nWork PC should send POST to:")
    print(f"  http://{ip_str}/status")
    print(f"\nJSON format:")
    print(f'  {{"status": 0}}  # 0-10')
    print("\n" + "="*50 + "\n")

except Exception as e:
    print(f"✗ HTTP server init failed: {e}")
    print("Make sure adafruit_httpserver is in lib/")
    supervisor.reload()

# ==================== DISPLAY FUNCTIONS ====================
def update_output(status):
    """Update output device based on status"""
    color = STATUS_COLORS.get(status, (255, 255, 255))
    name = STATUS_NAMES.get(status, "Unknown")

    if OUTPUT_DEVICE == "NEOPIXEL" and output_device:
        output_device.fill(color)
        output_device.show()

    elif OUTPUT_DEVICE == "RGB_LED" and output_device:
        # Convert 0-255 to 0-65535 duty cycle (inverted for common cathode)
        r = int((color[0] / 255) * 65535)
        g = int((color[1] / 255) * 65535)
        b = int((color[2] / 255) * 65535)

        output_device["red"].duty_cycle = r
        output_device["green"].duty_cycle = g
        output_device["blue"].duty_cycle = b

    elif OUTPUT_DEVICE == "OLED" and output_device:
        output_device["status_text"].text = name

    elif OUTPUT_DEVICE == "LED_MATRIX" and output_device:
        matrix = output_device["matrix"]

        # Map RGB to grayscale brightness (0-255) for the matrix
        # The IS31FL3731 uses grayscale, not RGB
        brightness = int((color[0] * 0.299 + color[1] * 0.587 + color[2] * 0.114))

        # Create different patterns based on status
        matrix.fill(0)  # Clear first

        if status == 0:  # Available - Green - Full brightness bars
            for y in range(7):
                for x in range(15):
                    matrix[x, y] = brightness if x % 3 == 0 else 0

        elif status in [1, 6, 7, 8]:  # Busy/Presenting/Meeting/Call - Red - Solid
            matrix.fill(brightness)

        elif status in [2, 3]:  # Away/BRB - Yellow - Blinking pattern
            for y in range(7):
                for x in range(15):
                    if (x + y) % 2 == 0:
                        matrix[x, y] = brightness

        elif status in [4, 5]:  # DND/Focusing - Purple - Border
            for x in range(15):
                matrix[x, 0] = brightness
                matrix[x, 6] = brightness
            for y in range(7):
                matrix[0, y] = brightness
                matrix[14, y] = brightness

        elif status == 9:  # Offline - Gray - Dim
            matrix.fill(brightness // 4)

        else:  # Unknown - White - Checkerboard
            for y in range(7):
                for x in range(15):
                    if (x + y) % 2 == 0:
                        matrix[x, y] = brightness

    # Log to console
    now = time.localtime()
    print(f"[{now[3]:02d}:{now[4]:02d}:{now[5]:02d}] Status: {name}")

# ==================== HTTP HANDLERS ====================
@server.route("/status", POST)
def handle_status(request: Request):
    """Handle POST /status requests from Work PC"""
    try:
        data = request.json()
        status = int(data.get("status", 10))

        # Validate status range
        if 0 <= status <= 10:
            update_output(status)
            return Response(request, '{"success":true}', content_type="application/json")
        else:
            return Response(request, '{"error":"Invalid status range (0-10)"}',
                          content_type="application/json", status=400)

    except Exception as e:
        print(f"✗ Error handling request: {e}")
        return Response(request, '{"error":"Invalid request"}',
                       content_type="application/json", status=400)

@server.route("/", "GET")
def handle_root(request: Request):
    """Handle GET / - show simple status page"""
    html = f"""<!DOCTYPE html>
<html>
<head>
    <title>Teams Status - Feather M0 WiFi</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {{ font-family: Arial; margin: 20px; background: #1e1e1e; color: #fff; }}
        .container {{ max-width: 600px; margin: 0 auto; }}
        .status {{ padding: 20px; background: #2d2d30; border-radius: 8px; margin: 20px 0; }}
        h1 {{ color: #00bcf2; }}
        code {{ background: #333; padding: 2px 6px; border-radius: 3px; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🚦 Teams Status - Feather M0 WiFi</h1>
        <div class="status">
            <h2>Server Info</h2>
            <p><strong>IP Address:</strong> {ip_str}</p>
            <p><strong>Port:</strong> {HTTP_PORT}</p>
            <p><strong>Output Device:</strong> {OUTPUT_DEVICE or "None"}</p>
        </div>
        <div class="status">
            <h2>API Endpoint</h2>
            <p><strong>POST</strong> <code>/status</code></p>
            <p>Body: <code>{{"status": 0}}</code></p>
            <p>Status codes: 0=Available, 1=Busy, 2=Away, etc.</p>
        </div>
        <div class="status">
            <h2>Work PC Setup</h2>
            <p>Configure your Work PC to send POST requests to:</p>
            <p><code>http://{ip_str}/status</code></p>
        </div>
    </div>
</body>
</html>"""
    return Response(request, html, content_type="text/html")

@server.route("/health", "GET")
def handle_health(request: Request):
    """Health check endpoint"""
    health = {
        "status": "healthy",
        "ip": ip_str,
        "output": OUTPUT_DEVICE or "none"
    }
    import json
    return Response(request, json.dumps(health), content_type="application/json")

# ==================== INITIAL STATE ====================
# Set initial status to Unknown
update_output(10)

if OUTPUT_DEVICE == "OLED" and output_device:
    output_device["status_text"].text = f"Ready: {ip_str}"

# ==================== MAIN SERVER LOOP ====================
print("Server starting...")
print("Press Ctrl+C to stop\n")

try:
    server.serve_forever(str(ip_str), HTTP_PORT)
except Exception as e:
    print(f"✗ Server error: {e}")
    supervisor.reload()
