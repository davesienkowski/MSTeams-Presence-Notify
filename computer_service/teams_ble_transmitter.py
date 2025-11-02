"""
Teams Status BLE Transmitter for RFduino
Monitors MS Teams status and broadcasts via Bluetooth Low Energy

Requirements:
    pip install bleak asyncio

Usage:
    python teams_ble_transmitter.py
"""

import asyncio
import os
import re
import json
import time
from datetime import datetime
from bleak import BleakScanner, BleakClient
from typing import Optional

# Configuration
RFDUINO_NAME = "RFduino"  # Change if you've renamed your RFduino/Simblee
# Simblee uses the same UUIDs as RFduino, but we'll use Simblee's actual UUIDs
RFDUINO_SERVICE_UUID = "0000fe84-0000-1000-8000-00805f9b34fb"  # Simblee service
RFDUINO_CHAR_UUID = "00002221-0000-1000-8000-00805f9b34fb"  # Simblee send characteristic
CHECK_INTERVAL = 5  # seconds

# Teams log paths
TEAMS_LOG_PATH = os.path.join(
    os.getenv("LOCALAPPDATA"),
    "Packages",
    "MSTeams_8wekyb3d8bbwe",
    "LocalCache",
    "Microsoft",
    "MSTeams",
    "Logs"
)

CLASSIC_TEAMS_LOG_PATH = os.path.join(
    os.getenv("APPDATA"),
    "Microsoft",
    "Teams",
    "logs.txt"
)

# Status mapping (matches PowerShell server)
STATUS_CODES = {
    "Available": 0,
    "Busy": 1,
    "Away": 2,
    "BeRightBack": 3,
    "DoNotDisturb": 4,
    "Focusing": 5,
    "Presenting": 6,
    "InAMeeting": 7,
    "InACall": 8,
    "Offline": 9,
    "Unknown": 10
}


def get_teams_status() -> dict:
    """Parse Teams logs to get current status"""
    try:
        # Check if Teams is running
        import psutil
        teams_running = any(
            p.name().lower() == "ms-teams.exe"
            for p in psutil.process_iter(['name'])
        )

        if not teams_running:
            return {
                "availability": "Offline",
                "code": STATUS_CODES["Offline"],
                "detected": True
            }

        # Determine which Teams version
        use_new_teams = os.path.exists(TEAMS_LOG_PATH)

        if use_new_teams:
            # New Teams: read from latest .log files
            log_files = []
            try:
                for file in os.listdir(TEAMS_LOG_PATH):
                    if file.endswith(".log"):
                        log_files.append(os.path.join(TEAMS_LOG_PATH, file))

                log_files.sort(key=os.path.getmtime, reverse=True)
                log_files = log_files[:3]  # Latest 3 files

                log_content = ""
                for log_file in log_files:
                    try:
                        with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                            # Read last 500 lines
                            lines = f.readlines()
                            log_content += ''.join(lines[-500:])
                    except Exception:
                        pass
            except Exception:
                return {"detected": False}
        else:
            # Classic Teams
            try:
                with open(CLASSIC_TEAMS_LOG_PATH, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                    log_content = ''.join(lines[-1000:])
            except Exception:
                return {"detected": False}

        if not log_content:
            return {"detected": False}

        # Parse status from log patterns (priority order)
        availability = "Unknown"

        if re.search(r"SetBadge Setting badge:.*doNotDisturb|Do not disturb", log_content, re.IGNORECASE):
            availability = "DoNotDisturb"
        elif re.search(r"SetBadge Setting badge:.*focusing", log_content, re.IGNORECASE):
            availability = "Focusing"
        elif re.search(r"SetBadge Setting badge:.*presenting", log_content, re.IGNORECASE):
            availability = "Presenting"
        elif re.search(r"SetBadge Setting badge:.*inameeting|InAMeeting", log_content, re.IGNORECASE):
            availability = "InAMeeting"
        elif re.search(r"SetBadge Setting badge:.*busy", log_content, re.IGNORECASE):
            availability = "Busy"
        elif re.search(r"SetBadge Setting badge:.*away", log_content, re.IGNORECASE):
            availability = "Away"
        elif re.search(r"SetBadge Setting badge:.*berightback|BeRightBack", log_content, re.IGNORECASE):
            availability = "BeRightBack"
        elif re.search(r"SetBadge Setting badge:.*available", log_content, re.IGNORECASE):
            availability = "Available"
        elif re.search(r"SetBadge Setting badge:.*offline", log_content, re.IGNORECASE):
            availability = "Offline"

        return {
            "availability": availability,
            "code": STATUS_CODES.get(availability, STATUS_CODES["Unknown"]),
            "detected": True
        }

    except Exception as e:
        print(f"Error parsing Teams logs: {e}")
        return {"detected": False}


async def find_rfduino() -> Optional[str]:
    """Scan for RFduino device and return its address"""
    print("Scanning for RFduino...")

    devices = await BleakScanner.discover(timeout=10.0)

    for device in devices:
        if device.name and RFDUINO_NAME in device.name:
            print(f"✓ Found RFduino: {device.name} ({device.address})")
            return device.address

    print(f"✗ RFduino not found (looking for '{RFDUINO_NAME}')")
    return None


async def send_status_to_rfduino(client: BleakClient, status: dict, char_uuid: str):
    """Send status code to RFduino via BLE"""
    try:
        # Send status code as single byte
        status_byte = bytes([status["code"]])
        await client.write_gatt_char(char_uuid, status_byte, response=False)

        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] Sent: {status['availability']} (code: {status['code']})")

    except Exception as e:
        print(f"Error sending to RFduino: {e}")


async def main():
    """Main monitoring loop"""
    print("\n" + "="*50)
    print("Teams Status BLE Transmitter for RFduino")
    print("="*50 + "\n")

    # Check dependencies
    try:
        import psutil
    except ImportError:
        print("ERROR: psutil not installed!")
        print("Install with: pip install psutil")
        return

    # Find RFduino
    rfduino_address = await find_rfduino()
    if not rfduino_address:
        print("\nTroubleshooting:")
        print("1. Make sure RFduino is powered on")
        print("2. Ensure Bluetooth is enabled on PC")
        print("3. Check if RFduino name matches (default: 'RFduino')")
        print("4. Try uploading the Arduino sketch first")
        return

    print(f"\nConnecting to RFduino at {rfduino_address}...")

    last_status_code = None

    async with BleakClient(rfduino_address) as client:
        print("✓ Connected to RFduino\n")

        # Discover services and find writable characteristic
        print("Discovering BLE characteristics...")

        # Find all writable characteristics (Simblee/RFduino has multiple)
        writable_chars = []
        for service in client.services:
            for char in service.characteristics:
                # Look for writable characteristic (properties include 'write' or 'write-without-response')
                if "write" in char.properties or "write-without-response" in char.properties:
                    writable_chars.append(char.uuid)
                    print(f"  Found writable: {char.uuid}")

        if not writable_chars:
            print("ERROR: No writable characteristics found!")
            return

        # Try to find Simblee receive characteristic (usually the second writable one, not Device Name)
        write_char = None
        for uuid in writable_chars:
            # Skip standard BLE characteristics (Device Name, etc.)
            if uuid.startswith("00002a"):  # Standard BLE characteristics start with 00002axx
                continue
            write_char = uuid
            print(f"✓ Using characteristic: {write_char}")
            break

        if not write_char:
            # Fallback to last writable characteristic if no custom one found
            write_char = writable_chars[-1] if writable_chars else None
            if write_char:
                print(f"⚠ Fallback to: {write_char}")

        if not write_char:
            print("ERROR: No suitable characteristic found!")
            return

        print(f"\nConfiguration:")
        print(f"  Check Interval: {CHECK_INTERVAL} seconds")
        print(f"  Teams Log Path: {TEAMS_LOG_PATH if os.path.exists(TEAMS_LOG_PATH) else CLASSIC_TEAMS_LOG_PATH}")
        print("\nMonitoring Teams status...\n")

        # Initial status check
        status = get_teams_status()
        if status.get("detected"):
            await send_status_to_rfduino(client, status, write_char)
            last_status_code = status["code"]
        else:
            print("Could not detect Teams status")

        # Main monitoring loop
        try:
            while True:
                await asyncio.sleep(CHECK_INTERVAL)

                status = get_teams_status()

                if status.get("detected"):
                    # Only send if status changed
                    if status["code"] != last_status_code:
                        await send_status_to_rfduino(client, status, write_char)
                        last_status_code = status["code"]

        except KeyboardInterrupt:
            print("\n\nShutting down...")
        except Exception as e:
            print(f"\nError: {e}")


if __name__ == "__main__":
    asyncio.run(main())
