#!/usr/bin/env python3
"""
MS Teams Status Push Client for macOS
Monitors Teams logs and pushes status updates to Raspberry Pi at home
Architecture: Work Mac (client) -> Raspberry Pi (server)
"""

import argparse
import os
import re
import sys
import time
from datetime import datetime
from glob import glob
from typing import Optional
import json

try:
    import requests
except ImportError:
    print("Error: 'requests' module not found. Install with: pip3 install requests")
    sys.exit(1)

# Teams log file location for macOS
TEAMS_LOG_PATH = os.path.expanduser(
    "~/Library/Application Support/Microsoft/Teams/Logs"
)
NEW_TEAMS_LOG_PATH = os.path.expanduser(
    "~/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams/Logs"
)

# Status mapping
STATUS_COLORS = {
    "Available": "#00FF00",
    "Busy": "#FF0000",
    "Away": "#FFFF00",
    "BeRightBack": "#FFFF00",
    "DoNotDisturb": "#800080",
    "InAMeeting": "#FF0000",
    "InACall": "#FF0000",
    "Offline": "#808080",
    "Unknown": "#FFFFFF",
}

STATUS_INDICATOR = {
    "Available": "[OK]",
    "Busy": "[!!]",
    "Away": "[--]",
    "BeRightBack": "[..]",
    "DoNotDisturb": "[XX]",
    "InAMeeting": "[!!]",
    "InACall": "[!!]",
    "Offline": "[  ]",
    "Unknown": "[??]",
}

# ANSI color codes
COLORS = {
    "Green": "\033[92m",
    "Red": "\033[91m",
    "Yellow": "\033[93m",
    "Magenta": "\033[95m",
    "Cyan": "\033[96m",
    "White": "\033[97m",
    "DarkGray": "\033[90m",
    "Reset": "\033[0m",
}

STATUS_DISPLAY_COLOR = {
    "Available": "Green",
    "Busy": "Red",
    "Away": "Yellow",
    "BeRightBack": "Yellow",
    "DoNotDisturb": "Magenta",
    "InAMeeting": "Red",
    "InACall": "Red",
    "Offline": "DarkGray",
    "Unknown": "White",
}


class TeamsPushClient:
    def __init__(self, raspberry_pi_ip: str, port: int, poll_interval: int, verbose: bool):
        self.raspberry_pi_ip = raspberry_pi_ip
        self.port = port
        self.poll_interval = poll_interval
        self.verbose = verbose

        self.last_status: Optional[str] = None
        self.last_activity: Optional[str] = None
        self.last_successful_send: Optional[datetime] = None
        self.update_count = 0
        self.status_history: list = []
        self.max_history = 5
        self.last_poll_time: Optional[datetime] = None
        self.is_connected = False

    def colorize(self, text: str, color: str) -> str:
        """Apply ANSI color to text."""
        return f"{COLORS.get(color, '')}{text}{COLORS['Reset']}"

    def get_teams_log_path(self) -> Optional[dict]:
        """Find the Teams log file location."""
        # Check for new Teams first
        if os.path.exists(NEW_TEAMS_LOG_PATH):
            return {"path": NEW_TEAMS_LOG_PATH, "is_new_teams": True}
        # Fall back to classic Teams
        if os.path.exists(TEAMS_LOG_PATH):
            return {"path": TEAMS_LOG_PATH, "is_new_teams": False}
        return None

    def get_teams_status(self) -> dict:
        """Read Teams logs and extract current status."""
        log_info = self.get_teams_log_path()
        if not log_info:
            return {"availability": "Unknown", "activity": "Unknown"}

        try:
            log_content = []
            if log_info["is_new_teams"]:
                # New Teams - find most recent log file
                log_files = glob(os.path.join(log_info["path"], "MSTeams_*.log"))
                log_files = [
                    f for f in log_files
                    if not any(x in f for x in ["Update", "SlimCore", "Launcher"])
                ]
                if log_files:
                    log_files.sort(key=os.path.getmtime, reverse=True)
                    with open(log_files[0], "r", errors="ignore") as f:
                        lines = f.readlines()
                        log_content = lines[-5000:] if len(lines) > 5000 else lines
            else:
                # Classic Teams
                log_file = os.path.join(log_info["path"], "logs.txt")
                if os.path.exists(log_file):
                    with open(log_file, "r", errors="ignore") as f:
                        lines = f.readlines()
                        log_content = lines[-5000:] if len(lines) > 5000 else lines

            if log_content:
                status_pattern = re.compile(
                    r"UserDataCrossCloudModule|UserPresenceAction|SetBadge.*status|"
                    r"StatusIndicatorStateService|NewActivity"
                )
                status_lines = [line for line in log_content if status_pattern.search(line)]

                if status_lines:
                    recent_status = status_lines[-50:]
                    for line in reversed(recent_status):
                        # Check various status patterns
                        match = re.search(
                            r"availability:\s*(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)[\s,}]",
                            line
                        )
                        if match:
                            return {"availability": match.group(1), "activity": match.group(1)}

                        match = re.search(
                            r"status\s+(Available|Busy|Away|BeRightBack|DoNotDisturb|Offline)[\s,]",
                            line
                        )
                        if match:
                            return {"availability": match.group(1), "activity": match.group(1)}

                        match = re.search(
                            r"Setting the taskbar overlay icon - (Available|Away)|"
                            r"NewActivity: (Available|Away)",
                            line
                        )
                        if match:
                            status = match.group(1) or match.group(2)
                            return {"availability": status, "activity": status}

                        match = re.search(r"NewActivity: (InAMeeting|InACall|Busy)", line)
                        if match:
                            return {"availability": match.group(1), "activity": match.group(1)}

                        if "NewActivity: BeRightBack" in line:
                            return {"availability": "BeRightBack", "activity": "BeRightBack"}

                        match = re.search(r"NewActivity: (DoNotDisturb|Presenting)", line)
                        if match:
                            return {"availability": "DoNotDisturb", "activity": "DoNotDisturb"}

                        if "NewActivity: Offline" in line:
                            return {"availability": "Offline", "activity": "Offline"}

            return {"availability": "Unknown", "activity": "Unknown"}

        except Exception as e:
            if self.verbose:
                print(f"Error reading logs: {e}")
            return {"availability": "Unknown", "activity": "Unknown"}

    def send_status_update(self, availability: str, activity: str) -> bool:
        """Send status update to Raspberry Pi."""
        url = f"http://{self.raspberry_pi_ip}:{self.port}/status"
        payload = {
            "availability": availability,
            "activity": activity,
            "color": STATUS_COLORS.get(availability, "#FFFFFF"),
            "timestamp": datetime.now().isoformat(),
        }

        try:
            response = requests.post(url, json=payload, timeout=3)
            return response.status_code == 200
        except Exception:
            return False

    def test_connection(self) -> bool:
        """Test connection to Raspberry Pi."""
        try:
            response = requests.get(
                f"http://{self.raspberry_pi_ip}:{self.port}/",
                timeout=3
            )
            return response.status_code == 200
        except Exception:
            return False

    def add_to_history(self, status: str, sent: bool):
        """Add status change to history."""
        self.status_history.append({
            "status": status,
            "time": datetime.now(),
            "sent": sent,
        })
        if len(self.status_history) > self.max_history:
            self.status_history = self.status_history[-self.max_history:]

    def clear_screen(self):
        """Clear the terminal screen."""
        os.system("clear")

    def hide_cursor(self):
        """Hide terminal cursor."""
        print("\033[?25l", end="")

    def show_cursor(self):
        """Show terminal cursor."""
        print("\033[?25h", end="")

    def move_cursor(self, row: int, col: int = 0):
        """Move cursor to specific position."""
        print(f"\033[{row};{col}H", end="")

    def draw_ui(self, current_status: str = "Unknown", last_update_time: str = "--:--:--",
                last_poll_time: str = "--:--:--", countdown: int = 0,
                connected: bool = False, updates_sent: int = 0):
        """Draw the full UI."""
        self.clear_screen()
        self.hide_cursor()

        indicator = STATUS_INDICATOR.get(current_status, "[??]")
        status_color = STATUS_DISPLAY_COLOR.get(current_status, "White")
        conn_color = "Green" if connected else "Red"
        conn_text = "Connected" if connected else "Disconnected"

        print()
        print(self.colorize("  ======================================================================", "Cyan"))
        print(self.colorize("                    MS Teams Status Push Client", "Cyan"))
        print(self.colorize("  ======================================================================", "Cyan"))
        print()

        # Config section
        print(self.colorize("  ----------------------------------------------------------------------", "DarkGray"))
        print(self.colorize("   Configuration", "White"))
        print(self.colorize("  ----------------------------------------------------------------------", "DarkGray"))
        print(f"{self.colorize('   Raspberry Pi:  ', 'DarkGray')}{self.colorize(self.raspberry_pi_ip, 'White')}"
              f"{self.colorize('     Port: ', 'DarkGray')}{self.colorize(str(self.port), 'White')}")
        print(f"{self.colorize('   Poll Interval: ', 'DarkGray')}{self.colorize(f'{self.poll_interval}s', 'White')}")
        print()

        # Services section
        print(self.colorize("  ----------------------------------------------------------------------", "DarkGray"))
        print(self.colorize("   Raspberry Pi Services", "White"))
        print(self.colorize("  ----------------------------------------------------------------------", "DarkGray"))
        print(f"{self.colorize('   Web Dashboard:   ', 'DarkGray')}"
              f"{self.colorize(f'http://{self.raspberry_pi_ip}:5000', 'Cyan')}")
        print(f"{self.colorize('   Status API:      ', 'DarkGray')}"
              f"{self.colorize(f'http://{self.raspberry_pi_ip}:{self.port}/status', 'Cyan')}")
        print(f"{self.colorize('   Home Assistant:  ', 'DarkGray')}"
              f"{self.colorize('MQTT (configure on Pi)', 'DarkGray')}")
        print(f"{self.colorize('   Notifications:   ', 'DarkGray')}"
              f"{self.colorize('ntfy.sh (configure on Pi)', 'DarkGray')}")
        print()

        # Current Status section
        print(self.colorize("  ----------------------------------------------------------------------", "DarkGray"))
        print(self.colorize("   Current Status", "White"))
        print(self.colorize("  ----------------------------------------------------------------------", "DarkGray"))
        print(f"   {self.colorize(indicator, status_color)} {self.colorize(current_status.ljust(15), status_color)}"
              f"{self.colorize(f'Last update: {last_update_time}', 'DarkGray')}")
        print()

        # History section
        print(self.colorize("  ----------------------------------------------------------------------", "DarkGray"))
        print(self.colorize("   Recent Changes", "White"))
        print(self.colorize("  ----------------------------------------------------------------------", "DarkGray"))

        for i in range(self.max_history):
            if i < len(self.status_history):
                entry = self.status_history[-(i + 1)]
                h_indicator = STATUS_INDICATOR.get(entry["status"], "[??]")
                h_color = STATUS_DISPLAY_COLOR.get(entry["status"], "White")
                h_time = entry["time"].strftime("%H:%M:%S")
                sent_text = "[Sent]" if entry["sent"] else "[Failed]"
                sent_color = "Green" if entry["sent"] else "Red"

                print(f"   {self.colorize(h_time, 'DarkGray')}  "
                      f"{self.colorize(h_indicator, h_color)} {self.colorize(entry['status'].ljust(14), h_color)}"
                      f"{self.colorize('-> Pi ', 'DarkGray')}{self.colorize(sent_text, sent_color)}")
            else:
                print(self.colorize("   -", "DarkGray"))
        print()

        # Connection section
        print(self.colorize("  ----------------------------------------------------------------------", "DarkGray"))
        print(f"   {self.colorize('Connection: ', 'DarkGray')}{self.colorize(conn_text.ljust(14), conn_color)}"
              f"{self.colorize('Updates sent: ', 'DarkGray')}{self.colorize(str(updates_sent), 'White')}")
        print(self.colorize("  ----------------------------------------------------------------------", "DarkGray"))
        print()

        # Footer
        print(f"  {self.colorize(f'Last poll: {last_poll_time}  |  Next in: {str(countdown).rjust(2)}s  |  Ctrl+C to stop', 'DarkGray')}")

    def update_footer(self, poll_time: str, countdown: int):
        """Update just the footer line with countdown."""
        self.move_cursor(42, 1)
        print(f"  {self.colorize(f'Last poll: {poll_time}  |  Next in: {str(countdown).rjust(2)}s  |  Ctrl+C to stop     ', 'DarkGray')}", end="")
        sys.stdout.flush()

    def run(self):
        """Main monitoring loop."""
        # Initial UI draw
        self.draw_ui(
            current_status="Unknown",
            connected=False,
            updates_sent=0
        )

        # Test initial connection
        self.is_connected = self.test_connection()

        consecutive_errors = 0
        max_consecutive_errors = 5
        last_check_time = datetime.now()
        # Trigger immediate first poll
        last_check_time = last_check_time.replace(
            second=last_check_time.second - self.poll_interval - 1
        )

        try:
            while True:
                now = datetime.now()
                seconds_since_last_check = (now - last_check_time).total_seconds()

                # Calculate countdown
                capped_seconds = min(seconds_since_last_check, self.poll_interval + 1)
                countdown = max(0, self.poll_interval - int(capped_seconds))

                # Update footer with countdown
                poll_time_str = (
                    self.last_poll_time.strftime("%H:%M:%S")
                    if self.last_poll_time else "--:--:--"
                )
                self.update_footer(poll_time_str, countdown)

                # Time to poll?
                if seconds_since_last_check >= self.poll_interval:
                    self.last_poll_time = now
                    last_check_time = now

                    try:
                        status = self.get_teams_status()
                        update_time_str = now.strftime("%H:%M:%S")

                        # Check if status changed
                        if (status["availability"] != self.last_status or
                                status["activity"] != self.last_activity):

                            # Send update to Raspberry Pi
                            sent = self.send_status_update(
                                status["availability"],
                                status["activity"]
                            )

                            if sent:
                                self.update_count += 1
                                self.is_connected = True
                                self.last_successful_send = now
                                consecutive_errors = 0
                            else:
                                self.is_connected = False
                                consecutive_errors += 1

                            # Add to history
                            self.add_to_history(status["availability"], sent)

                            self.last_status = status["availability"]
                            self.last_activity = status["activity"]

                            # Redraw full UI to show changes
                            self.draw_ui(
                                current_status=status["availability"],
                                last_update_time=update_time_str,
                                last_poll_time=poll_time_str,
                                countdown=countdown,
                                connected=self.is_connected,
                                updates_sent=self.update_count
                            )

                        # Check for too many consecutive errors
                        if consecutive_errors >= max_consecutive_errors:
                            self.is_connected = self.test_connection()
                            consecutive_errors = 0

                    except Exception as e:
                        if self.verbose:
                            print(f"Error: {e}")

                # Short sleep for responsive countdown
                time.sleep(0.5)

        except KeyboardInterrupt:
            pass
        finally:
            self.show_cursor()
            print("\n")
            print(self.colorize("  Stopped.", "Yellow"))


def main():
    parser = argparse.ArgumentParser(
        description="MS Teams Status Push Client for macOS"
    )
    parser.add_argument(
        "--ip",
        default="192.168.50.137",
        help="Raspberry Pi IP address (default: 192.168.50.137)"
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8080,
        help="Server port (default: 8080)"
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=5,
        help="Poll interval in seconds (default: 5)"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose debug output"
    )

    args = parser.parse_args()

    client = TeamsPushClient(
        raspberry_pi_ip=args.ip,
        port=args.port,
        poll_interval=args.interval,
        verbose=args.verbose
    )
    client.run()


if __name__ == "__main__":
    main()
