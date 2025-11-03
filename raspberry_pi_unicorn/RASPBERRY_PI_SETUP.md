# Raspberry Pi Setup Guide - PUSH Architecture

Complete setup guide for Raspberry Pi OS (Bookworm and newer)

---

## 🐍 Python Virtual Environment Setup

Modern Raspberry Pi OS requires using virtual environments for Python packages.

### Step 1: Install Python Dependencies

```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn

# Install system Python packages
sudo apt update
sudo apt install -y python3-pip python3-venv python3-full

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Your prompt should now show (venv)
```

### Step 2: Install Python Packages

```bash
# Make sure venv is activated (you should see "(venv)" in prompt)
pip install -r requirements_integrated.txt
```

**Expected output:**
```
Successfully installed Flask-3.0.0 flask-cors-4.0.0 paho-mqtt-1.6.1 pyyaml-6.0.1 ...
```

### Step 3: Install Unicorn HAT Library

The Unicorn HAT library needs special handling:

```bash
# Still in venv
pip install unicornhat

# Or use Pimoroni installer (if pip fails)
curl -sS https://get.pimoroni.com/unicornhat | bash
```

---

## ⚙️ Configuration

### Create Config File

```bash
# Copy template
cp config_push.yaml my_config.yaml

# Edit configuration
nano my_config.yaml
```

**Minimum required changes:**
```yaml
notifications:
  ntfy_topic: "myteamspresence_yourname_12345"  # Make this unique!
```

**Optional: Enable Home Assistant**
```yaml
homeassistant:
  enabled: true
  mqtt_broker: "homeassistant.local"
  mqtt_username: "your_user"
  mqtt_password: "your_pass"
```

---

## 🚀 Running the Application

### Manual Run (Testing)

```bash
# Activate venv first
source ~/MSTeams-Presence-Notify/raspberry_pi_unicorn/venv/bin/activate

# Run with sudo (needed for GPIO/Unicorn HAT access)
sudo venv/bin/python3 teams_status_integrated_push.py
```

**Why sudo?**
- Unicorn HAT requires GPIO access
- GPIO requires root privileges on Raspberry Pi

---

## 🔧 Auto-Start on Boot (systemd)

### Create Service File

```bash
sudo nano /etc/systemd/system/teams-presence-push.service
```

**Paste this (adjust paths if needed):**

```ini
[Unit]
Description=MS Teams Presence Monitor (PUSH)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn
ExecStart=/home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn/venv/bin/python3 /home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn/teams_status_integrated_push.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Environment
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
```

**Key points:**
- `User=root` - Required for GPIO access
- Uses venv Python path
- Auto-restarts on failure

### Enable and Start Service

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable (start on boot)
sudo systemctl enable teams-presence-push

# Start now
sudo systemctl start teams-presence-push

# Check status
sudo systemctl status teams-presence-push
```

**Expected output:**
```
● teams-presence-push.service - MS Teams Presence Monitor (PUSH)
   Loaded: loaded
   Active: active (running)
```

### View Logs

```bash
# Real-time logs
sudo journalctl -u teams-presence-push -f

# Last 50 lines
sudo journalctl -u teams-presence-push -n 50

# Today's logs
sudo journalctl -u teams-presence-push --since today
```

---

## 🌐 Network Setup

### Find Your IP Address

```bash
hostname -I
```

Example output: `192.168.50.137`

### Configure Firewall (if enabled)

```bash
# Allow status server (receives from work PC)
sudo ufw allow 8080/tcp

# Allow web dashboard
sudo ufw allow 5000/tcp

# Check firewall status
sudo ufw status
```

### Test Web Dashboard

From your phone or another device:
```
http://192.168.50.137:5000
```

---

## 🧪 Testing

### Test Unicorn HAT

```bash
# Activate venv
source ~/MSTeams-Presence-Notify/raspberry_pi_unicorn/venv/bin/activate

# Test script
sudo venv/bin/python3 -c "
import unicornhat as unicorn
unicorn.set_layout(unicorn.HAT)
unicorn.brightness(0.5)
unicorn.set_all(0, 255, 0)  # Green
unicorn.show()
import time
time.sleep(2)
unicorn.clear()
unicorn.show()
print('Unicorn HAT test complete!')
"
```

**Expected:** Unicorn HAT should light up green for 2 seconds

### Test Status Endpoint

```bash
# From Raspberry Pi
curl http://localhost:8080/

# Should return HTML page showing "Teams Status Server (PUSH)"
```

### Test from Work PC

From your Windows PC PowerShell:
```powershell
Invoke-RestMethod -Uri "http://192.168.50.137:8080/" -Method GET
```

---

## 🐛 Troubleshooting

### "ModuleNotFoundError: No module named 'unicornhat'"

**Solution:**
```bash
source ~/MSTeams-Presence-Notify/raspberry_pi_unicorn/venv/bin/activate
pip install unicornhat

# Or use Pimoroni installer
curl -sS https://get.pimoroni.com/unicornhat | bash
```

### "Permission denied" for GPIO

**Solution:**
- Run with `sudo`
- Use `User=root` in systemd service

### Service won't start

**Check logs:**
```bash
sudo journalctl -u teams-presence-push -n 50
```

**Common issues:**
1. Wrong Python path in service file
2. Missing dependencies
3. Config file not found
4. GPIO permission issues

**Fix:**
```bash
# Verify venv path
ls ~/MSTeams-Presence-Notify/raspberry_pi_unicorn/venv/bin/python3

# Verify dependencies
source ~/MSTeams-Presence-Notify/raspberry_pi_unicorn/venv/bin/activate
pip list

# Test manual run
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
sudo venv/bin/python3 teams_status_integrated_push.py
```

### "externally-managed-environment" error

**You're not using the venv!**

Always activate first:
```bash
source ~/MSTeams-Presence-Notify/raspberry_pi_unicorn/venv/bin/activate
```

Or use venv Python directly:
```bash
~/MSTeams-Presence-Notify/raspberry_pi_unicorn/venv/bin/pip install ...
```

### Web dashboard not accessible

**Check Flask is running:**
```bash
sudo lsof -i :5000
```

**Check firewall:**
```bash
sudo ufw status
sudo ufw allow 5000/tcp
```

**Check service logs:**
```bash
sudo journalctl -u teams-presence-push -f
```

---

## 📋 Service Management Commands

```bash
# Start
sudo systemctl start teams-presence-push

# Stop
sudo systemctl stop teams-presence-push

# Restart
sudo systemctl restart teams-presence-push

# Status
sudo systemctl status teams-presence-push

# Enable auto-start
sudo systemctl enable teams-presence-push

# Disable auto-start
sudo systemctl disable teams-presence-push

# View logs (real-time)
sudo journalctl -u teams-presence-push -f

# View logs (last 100 lines)
sudo journalctl -u teams-presence-push -n 100
```

---

## 🔄 Updating

When you pull new code:

```bash
cd ~/MSTeams-Presence-Notify
git pull

cd raspberry_pi_unicorn
source venv/bin/activate

# Update dependencies
pip install --upgrade -r requirements_integrated.txt

# Restart service
sudo systemctl restart teams-presence-push
```

---

## 📊 System Resources

### Check Resource Usage

```bash
# CPU and memory
htop

# Disk usage
df -h

# Process info
ps aux | grep python
```

### Typical Usage
- **CPU:** 5-10% (animations running)
- **RAM:** 50-80 MB
- **Storage:** <100 MB total

---

## 🎯 Quick Commands Reference

```bash
# Setup (one-time)
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
python3 -m venv venv
source venv/bin/activate
pip install -r requirements_integrated.txt

# Run manually
source venv/bin/activate
sudo venv/bin/python3 teams_status_integrated_push.py

# Service management
sudo systemctl start teams-presence-push    # Start
sudo systemctl stop teams-presence-push     # Stop
sudo systemctl status teams-presence-push   # Status
sudo journalctl -u teams-presence-push -f   # Logs

# Network info
hostname -I                                  # Get IP
sudo ufw allow 8080/tcp                     # Open port
curl http://localhost:8080/                 # Test
```

---

## 🆘 Still Having Issues?

### Collect Debug Info

```bash
# System info
cat /etc/os-release
python3 --version
pip --version

# Service status
sudo systemctl status teams-presence-push

# Recent logs
sudo journalctl -u teams-presence-push -n 100 > ~/debug.log

# Network info
hostname -I
sudo netstat -tlnp | grep -E '(8080|5000)'

# Python packages
source venv/bin/activate
pip list > ~/packages.log
```

### Common Solutions

**Problem:** GPIO access denied
```bash
# Add user to gpio group
sudo usermod -a -G gpio pi

# Or run with sudo
sudo venv/bin/python3 teams_status_integrated_push.py
```

**Problem:** Unicorn HAT not lighting up
```bash
# Check HAT is properly seated on GPIO pins
# Try re-installing library
pip install --force-reinstall unicornhat
```

**Problem:** Can't connect from work PC
```bash
# Check firewall
sudo ufw status

# Test locally first
curl http://localhost:8080/

# Check service is running
sudo systemctl status teams-presence-push
```

---

**Setup complete!** 🎉

**Next step:** Configure your work PC with [QUICK_SETUP_PUSH.md](QUICK_SETUP_PUSH.md)
