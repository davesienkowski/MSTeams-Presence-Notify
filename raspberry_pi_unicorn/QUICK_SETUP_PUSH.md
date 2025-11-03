# Quick Setup Guide - PUSH Architecture

**5-minute setup for Teams presence monitoring with mobile integration**

---

## 🎯 What You're Building

```
Work PC (monitors Teams) → PUSHES → Raspberry Pi (displays + web + notifications + HA)
```

---

## 📦 Requirements

- ✅ Windows PC with Microsoft Teams
- ✅ Raspberry Pi 3+ with Unicorn HAT
- ✅ Both connected to internet (can be different networks!)
- ✅ Mobile phone for notifications

---

## 🚀 Step 1: Setup Raspberry Pi (5 minutes)

### Install Dependencies

```bash
cd ~/MSTeams-Presence-Notify/raspberry_pi_unicorn
sudo pip3 install -r requirements_integrated.txt
```

### Configure

```bash
# Copy config template
cp config_push.yaml my_config.yaml
nano my_config.yaml
```

**Change ONLY this line:**
```yaml
notifications:
  ntfy_topic: "myteamspresence_YOURNAME_12345"  # Make it unique!
```

### Run Server

```bash
sudo python3 teams_status_integrated_push.py
```

You should see:
```
Server listening on port: 8080
Work PC should POST to: http://<raspberry-pi-ip>:8080/status
```

**📝 Note your Raspberry Pi's IP address:**
```bash
hostname -I
```
Example: `192.168.50.137`

---

## 🖥️ Step 2: Setup Work PC (2 minutes)

### Edit Push Client

```powershell
cd D:\Repos\MSTeams-Presence-Notify\powershell_service
notepad TeamsPushClient.ps1
```

**Change line 6 to YOUR Raspberry Pi IP:**
```powershell
[string]$RaspberryPiIP = "192.168.50.137",  # ← Put your Pi's IP here
```

### Run Push Client

```powershell
powershell -ExecutionPolicy Bypass -File TeamsPushClient.ps1
```

You should see:
```
✓ Successfully connected to Raspberry Pi at 192.168.50.137
Status changed: Unknown → Available
✓ Update sent successfully
```

---

## 📱 Step 3: Mobile Setup (3 minutes)

### Web Dashboard

On your phone, open:
```
http://192.168.50.137:5000
```
(Use your actual Pi IP)

**Add to home screen:**
- iOS: Share → Add to Home Screen
- Android: Menu → Add to Home screen

### Push Notifications

1. **Install ntfy app** ([Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) | [iOS](https://apps.apple.com/us/app/ntfy/id1625396347))

2. **Subscribe:**
   - Open app
   - Tap "+"
   - Enter your topic: `myteamspresence_YOURNAME_12345`
   - Tap "Subscribe"

3. **Test:**
   - Change your Teams status
   - You should get a notification!

---

## ✅ Verification

### Check Everything Works

**Raspberry Pi:**
- [ ] Unicorn HAT shows green (if Available)
- [ ] Web dashboard accessible from phone
- [ ] Console shows "Status changed: ..."

**Work PC:**
- [ ] PowerShell shows "Update sent successfully"
- [ ] No connection errors

**Mobile:**
- [ ] Web dashboard loads and shows current status
- [ ] Push notification received when status changes

---

## 🏠 Optional: Home Assistant (10 minutes)

### Enable MQTT

Edit `my_config.yaml` on Raspberry Pi:
```yaml
homeassistant:
  enabled: true
  mqtt_broker: "homeassistant.local"
  mqtt_port: 1883
  mqtt_username: "your_user"
  mqtt_password: "your_pass"
```

Restart:
```bash
sudo systemctl restart teams-presence-push
```

### Check Home Assistant

Go to **Developer Tools → States**

Search for: `sensor.teams_presence_status`

---

## 🔧 Auto-Start Setup

### Raspberry Pi (systemd)

```bash
sudo nano /etc/systemd/system/teams-presence-push.service
```

```ini
[Unit]
Description=MS Teams Presence (PUSH)
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/MSTeams-Presence-Notify/raspberry_pi_unicorn
ExecStart=/usr/bin/python3 teams_status_integrated_push.py
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable teams-presence-push
sudo systemctl start teams-presence-push
```

### Work PC (Task Scheduler)

1. Open **Task Scheduler**
2. Create Basic Task
3. **Trigger:** At logon
4. **Action:** Start program
5. **Program:** `powershell.exe`
6. **Arguments:** `-ExecutionPolicy Bypass -File "D:\Repos\MSTeams-Presence-Notify\powershell_service\TeamsPushClient.ps1"`

---

## 🐛 Troubleshooting

### "Cannot reach Raspberry Pi"

**From work PC, test connection:**
```powershell
Invoke-RestMethod -Uri "http://192.168.50.137:8080/" -Method GET
```

If this fails:
- Verify Pi IP address is correct
- Check Pi is on and running
- Try ping: `ping 192.168.50.137`

### "No status updates"

**Check Teams is running:**
```powershell
Get-Process -Name "ms-teams"
```

**Check logs are accessible:**
```powershell
Test-Path "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs\"
```

### "Push notifications not working"

- Verify topic is unique (not "myteamspresence")
- Check phone notifications are enabled
- Test manually: `curl -d "Test" https://ntfy.sh/your_topic`

### "Web dashboard not loading"

**On Raspberry Pi:**
```bash
sudo lsof -i :5000  # Should show python process
sudo systemctl status teams-presence-push
```

---

## 📚 Next Steps

Once everything works:

1. **Setup Home Assistant automations** (turn lights red when busy)
2. **Add to startup** (Task Scheduler on PC, systemd on Pi)
3. **Secure the connection** (VPN or SSH tunnel)
4. **Customize animations** (change `animation_mode` in config)
5. **Monitor reliability** (check logs occasionally)

---

## 🆘 Still Need Help?

### View Logs

**Raspberry Pi:**
```bash
sudo journalctl -u teams-presence-push -f
```

**Work PC:**
- Check PowerShell window for errors
- Add `-Verbose` flag to TeamsPushClient.ps1

### Read Documentation

- **Complete Setup:** [README_INTEGRATED_PUSH.md](README_INTEGRATED_PUSH.md)
- **Architecture:** [ARCHITECTURE_COMPARISON.md](ARCHITECTURE_COMPARISON.md)
- **Home Assistant:** [homeassistant_config_example.yaml](homeassistant_config_example.yaml)

---

**Total Setup Time: ~15 minutes** ⏱️

**Enjoy your Teams presence monitor!** 🎉
