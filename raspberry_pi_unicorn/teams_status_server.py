#!/usr/bin/env python3
"""
MS Teams Presence HTTP Server for Raspberry Pi with Unicorn HAT
Receives Teams status updates pushed from work PC and displays on LED matrix

Hardware: Raspberry Pi 3 Model B+ + Pimoroni Unicorn HAT
Network: Acts as HTTP server, receives status from work PC (push architecture)
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

# Configuration
SERVER_PORT = 8080  # Port to listen on
BRIGHTNESS = 0.5  # LED brightness (0.0 to 1.0)
ANIMATION_MODE = "pulse"  # Options: solid, pulse, gradient, ripple, spinner

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

# Global state
current_status = "Unknown"
shutdown_flag = False
animation_thread = None


def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    global shutdown_flag
    print("\n\nShutting down server...")
    shutdown_flag = True
    clear_display()
    sys.exit(0)


def setup_unicorn():
    """Initialize Unicorn HAT"""
    unicorn.set_layout(unicorn.HAT)
    unicorn.rotation(0)  # Adjust rotation if needed (0, 90, 180, 270)
    unicorn.brightness(BRIGHTNESS)
    print(f"Unicorn HAT initialized: 8x8 matrix at {int(BRIGHTNESS * 100)}% brightness")


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
        # Create sine wave for smooth pulsing
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
        intensity = (7 - y) / 7  # Fade from top to bottom
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
                # Calculate distance from center
                distance = math.sqrt((x - center_x)**2 + (y - center_y)**2)
                # Create wave effect
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

        # Draw spinning line
        for radius in range(5):
            x = int(center_x + radius * math.cos(angle))
            y = int(center_y + radius * math.sin(angle))
            if 0 <= x < 8 and 0 <= y < 8:
                intensity = 1.0 - (radius / 5)
                unicorn.set_pixel(x, y, int(r * intensity), int(g * intensity), int(b * intensity))

        unicorn.show()
        time.sleep(duration / steps)


def animation_loop():
    """Background thread for animations"""
    global current_status

    while not shutdown_flag:
        color = STATUS_COLORS.get(current_status, STATUS_COLORS["Unknown"])

        if ANIMATION_MODE == "solid":
            set_solid_color(color)
            time.sleep(0.1)
        elif ANIMATION_MODE == "pulse":
            pulse_animation(color, duration=2.0)
        elif ANIMATION_MODE == "gradient":
            gradient_animation(color)
            time.sleep(0.5)
        elif ANIMATION_MODE == "ripple":
            ripple_animation(color, duration=1.5)
        elif ANIMATION_MODE == "spinner":
            spinner_animation(color, duration=1.5)
        else:
            set_solid_color(color)
            time.sleep(0.1)


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


class TeamsStatusHandler(BaseHTTPRequestHandler):
    """HTTP request handler for receiving Teams status updates"""

    def log_message(self, format, *args):
        """Custom logging to show status updates"""
        if "POST" in format:
            print(f"[{self.log_date_time_string()}] {format % args}")

    def do_POST(self):
        """Handle POST requests with status updates"""
        global current_status

        if self.path == "/status":
            try:
                # Read request body
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)

                # Parse JSON
                data = json.loads(post_data.decode('utf-8'))
                new_status = data.get("availability", "Unknown")

                # Update status if changed
                if new_status != current_status:
                    print(f"Status changed: {current_status} → {new_status}")
                    current_status = new_status

                # Send success response
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {"status": "ok", "received": new_status}
                self.wfile.write(json.dumps(response).encode('utf-8'))

            except Exception as e:
                print(f"Error processing request: {e}")
                self.send_response(400)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                error_response = {"status": "error", "message": str(e)}
                self.wfile.write(json.dumps(error_response).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        """Handle GET requests for status check"""
        if self.path == "/status":
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                "current_status": current_status,
                "color": "#{:02x}{:02x}{:02x}".format(*STATUS_COLORS.get(current_status, (255, 255, 255)))
            }
            self.wfile.write(json.dumps(response).encode('utf-8'))
        elif self.path == "/":
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            html = f"""
            <html>
            <head><title>Teams Status Server</title></head>
            <body>
                <h1>MS Teams Presence - Raspberry Pi Unicorn HAT</h1>
                <p>Current Status: <strong>{current_status}</strong></p>
                <p>Server is running and ready to receive status updates.</p>
                <p>POST updates to: <code>http://RASPBERRY_PI_IP:8080/status</code></p>
            </body>
            </html>
            """
            self.wfile.write(html.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()


def main():
    """Main server loop"""
    global animation_thread

    # Setup signal handler for clean shutdown
    signal.signal(signal.SIGINT, signal_handler)

    print("=" * 60)
    print("MS Teams Presence Server - Raspberry Pi Unicorn HAT")
    print("=" * 60)
    print(f"Server listening on port: {SERVER_PORT}")
    print(f"Animation mode: {ANIMATION_MODE}")
    print(f"Brightness: {int(BRIGHTNESS * 100)}%")
    print()
    print("Work PC should POST status updates to:")
    print(f"  http://<raspberry-pi-ip>:{SERVER_PORT}/status")
    print()
    print("Press Ctrl+C to exit")
    print()

    # Initialize Unicorn HAT
    setup_unicorn()
    startup_animation()

    # Start animation thread
    animation_thread = threading.Thread(target=animation_loop, daemon=True)
    animation_thread.start()

    # Start HTTP server
    server_address = ('', SERVER_PORT)
    httpd = HTTPServer(server_address, TeamsStatusHandler)

    print(f"Server started successfully on port {SERVER_PORT}")
    print("Waiting for status updates from work PC...")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.shutdown()
        clear_display()


if __name__ == "__main__":
    main()
