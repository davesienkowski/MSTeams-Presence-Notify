#!/usr/bin/env python3
"""
MS Teams Presence Notification for Raspberry Pi with Unicorn HAT
Displays Teams status on an 8x8 WS2812B RGB LED matrix

Hardware: Raspberry Pi 3 Model B+ + Pimoroni Unicorn HAT
"""

import unicornhat as unicorn
import requests
import time
import signal
import sys
from colorsys import hsv_to_rgb
import math

# Configuration
SERVER_URL = "http://YOUR_PC_IP:8080/status"  # Change to your PC's IP
POLL_INTERVAL = 5  # Seconds between status checks
BRIGHTNESS = 0.5  # LED brightness (0.0 to 1.0)

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

# Animation modes
ANIMATION_MODE = "pulse"  # Options: solid, pulse, gradient, ripple, spinner

# Global state
current_status = None
shutdown_flag = False


def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    global shutdown_flag
    print("\n\nShutting down...")
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


def get_teams_status():
    """Fetch current Teams status from PowerShell server"""
    try:
        response = requests.get(SERVER_URL, timeout=3)
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


def display_status(status):
    """Display status with selected animation"""
    color = STATUS_COLORS.get(status, STATUS_COLORS["Unknown"])

    if ANIMATION_MODE == "solid":
        set_solid_color(color)
    elif ANIMATION_MODE == "pulse":
        pulse_animation(color, duration=2.0)
    elif ANIMATION_MODE == "gradient":
        gradient_animation(color)
    elif ANIMATION_MODE == "ripple":
        ripple_animation(color, duration=1.5)
    elif ANIMATION_MODE == "spinner":
        spinner_animation(color, duration=1.5)
    else:
        set_solid_color(color)


def startup_animation():
    """Rainbow animation on startup"""
    print("Running startup animation...")
    for hue in range(360):
        r, g, b = [int(c * 255) for c in hsv_to_rgb(hue / 360.0, 1.0, 1.0)]
        set_solid_color((r, g, b))
        time.sleep(0.005)
    clear_display()
    time.sleep(0.5)


def main():
    """Main loop"""
    global current_status

    # Setup signal handler for clean shutdown
    signal.signal(signal.SIGINT, signal_handler)

    print("=" * 50)
    print("MS Teams Presence - Raspberry Pi Unicorn HAT")
    print("=" * 50)
    print(f"Server URL: {SERVER_URL}")
    print(f"Poll interval: {POLL_INTERVAL} seconds")
    print(f"Animation mode: {ANIMATION_MODE}")
    print(f"Brightness: {int(BRIGHTNESS * 100)}%")
    print("\nPress Ctrl+C to exit\n")

    # Initialize Unicorn HAT
    setup_unicorn()
    startup_animation()

    # Main monitoring loop
    connection_errors = 0
    max_connection_errors = 5

    while not shutdown_flag:
        status = get_teams_status()

        if status is None:
            # Connection error
            connection_errors += 1
            if connection_errors >= max_connection_errors:
                print(f"Too many connection errors ({connection_errors}), showing error state...")
                set_solid_color((255, 0, 0))  # Red for error
            time.sleep(POLL_INTERVAL)
            continue

        # Reset error counter on successful connection
        connection_errors = 0

        # Update display if status changed
        if status != current_status:
            print(f"Status changed: {current_status} → {status}")
            current_status = status
            display_status(status)
        elif ANIMATION_MODE != "solid":
            # Keep animating even if status hasn't changed
            display_status(status)

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
