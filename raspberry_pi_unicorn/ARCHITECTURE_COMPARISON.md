# Architecture Comparison: PUSH vs PULL

This project supports TWO different architectures for communicating between your work PC and Raspberry Pi.

---

## 🏗️ YOUR SETUP: PUSH Architecture (Recommended)

```
Work PC (Office)                    Raspberry Pi (Home/Desk)
┌────────────────────┐              ┌─────────────────────────┐
│ TeamsPushClient.ps1│─────POST────▶│ Port 8080 (HTTP Server) │
│ Monitors Teams logs│              │ Unicorn HAT Display     │
│ Sends when changed │              │ Web Dashboard (Port5000)│
└────────────────────┘              └─────────────────────────┘
```

### Files Used (PUSH)
- **Work PC**: `powershell_service/TeamsPushClient.ps1`
- **Raspberry Pi**: `raspberry_pi_unicorn/teams_status_integrated_push.py`
- **Config**: `raspberry_pi_unicorn/config_push.yaml`

### How It Works
1. Work PC monitors Teams logs locally
2. When status changes, POST request sent to Raspberry Pi
3. Raspberry Pi receives update and displays on Unicorn HAT
4. Web dashboard, notifications, and HA integration happen on Pi

### Advantages ✅
- **Cross-network compatible** - Work PC and Pi can be on different networks
- **Firewall friendly** - Only outbound connection from work PC needed
- **Instant updates** - Status sent immediately when changed
- **No polling** - Lower network overhead
- **Simpler work PC** - No server to run on work machine
- **Remote accessible** - Easy to access Pi from anywhere

### Setup Steps
1. **Raspberry Pi**: Run `teams_status_integrated_push.py`
2. **Work PC**: Edit IP in `TeamsPushClient.ps1` and run
3. Done!

---

## 🔄 ALTERNATIVE: PULL Architecture (Original Design)

```
Work PC (Office)                    Raspberry Pi (Home/Desk)
┌────────────────────┐              ┌─────────────────────────┐
│ TeamsStatusServer  │◀─────GET─────│ teams_status_integrated │
│ Port 8080 (HTTP)   │              │ Polls every 5 seconds   │
│ Monitors Teams logs│              │ Unicorn HAT Display     │
└────────────────────┘              └─────────────────────────┘
```

### Files Used (PULL)
- **Work PC**: `powershell_service/TeamsStatusServer.ps1`
- **Raspberry Pi**: `raspberry_pi_unicorn/teams_status_integrated.py`
- **Config**: `raspberry_pi_unicorn/config.yaml`

### How It Works
1. Work PC runs HTTP server on port 8080
2. Raspberry Pi polls server every 5 seconds
3. Pi fetches current status via GET request
4. Pi displays on Unicorn HAT and runs integrations

### Advantages ✅
- **Simple setup** - Both devices on same network
- **Proven design** - Common pattern in many projects
- **Pi controls timing** - Can adjust poll frequency
- **Multiple clients** - Many devices can poll same server

### Disadvantages ❌
- **Same network required** - Both must be on local network
- **Firewall issues** - Need to expose port 8080 on work PC
- **Polling overhead** - Network traffic every 5 seconds
- **Latency** - Up to 5 second delay for status changes
- **Work PC complexity** - Must run HTTP server

---

## 📊 Quick Comparison

| Feature | PUSH (Your Setup) | PULL (Alternative) |
|---------|-------------------|-------------------|
| **Cross-network** | ✅ Yes | ❌ No (same network) |
| **Latency** | ⚡ Instant | 🐌 Up to 5s |
| **Firewall** | ✅ Friendly | ⚠️ Port forwarding needed |
| **Work PC Load** | 🟢 Low (client) | 🟡 Medium (server) |
| **Network Traffic** | 🟢 Minimal | 🟡 Continuous polling |
| **Setup Complexity** | 🟢 Simple | 🟢 Simple |
| **Reliability** | ✅ High | ✅ High |
| **VPN Friendly** | ✅ Yes | ⚠️ Depends |

---

## 🎯 Which Should You Use?

### Use PUSH (Your Current Setup) When:
- ✅ Work PC and Pi on **different networks**
- ✅ Work PC is at **office**, Pi at **home**
- ✅ You want **instant updates**
- ✅ You want **minimal work PC setup**
- ✅ Corporate firewall blocks **inbound connections**

### Use PULL When:
- ✅ Both devices on **same local network**
- ✅ You prefer **Pi controls polling**
- ✅ Multiple devices need to **read status**
- ✅ You want **standard HTTP server pattern**

---

## 🔄 Switching Between Architectures

### From PULL to PUSH (Moving to Your Setup)

**On Work PC:**
```powershell
# Stop the server
Stop TeamsStatusServer.ps1

# Start the push client instead
cd powershell_service
powershell -ExecutionPolicy Bypass -File TeamsPushClient.ps1
```

**On Raspberry Pi:**
```bash
# Stop old service
sudo systemctl stop teams-presence

# Start new push receiver
sudo python3 teams_status_integrated_push.py
```

### From PUSH to PULL

**On Work PC:**
```powershell
# Stop the push client
Stop TeamsPushClient.ps1

# Start the server instead
cd powershell_service
powershell -ExecutionPolicy Bypass -File TeamsStatusServer.ps1
```

**On Raspberry Pi:**
```bash
# Stop push receiver
sudo systemctl stop teams-presence-push

# Start pull client
sudo python3 teams_status_integrated.py
```

---

## 🔐 Security Comparison

### PUSH Architecture Security

**Threat Model:**
- Work PC → Pi: Status data transmitted over network
- Pi: Publicly accessible endpoint (port 8080)

**Mitigations:**
- Add authentication to POST endpoint
- Use HTTPS with self-signed cert
- Setup VPN tunnel (best option)
- IP whitelist on Pi firewall

**Example SSH Tunnel:**
```bash
# From work PC
ssh -R 8080:localhost:8080 user@raspberry-pi

# TeamsPushClient.ps1 uses localhost:8080
```

### PULL Architecture Security

**Threat Model:**
- Work PC: Exposed HTTP server
- Network: Continuous polling traffic

**Mitigations:**
- Use VPN for communication
- Add API key authentication
- Restrict access via firewall
- HTTPS with certificate

---

## 🚀 Performance Comparison

### Network Traffic

**PUSH:**
- Idle: 0 bytes
- Status change: ~500 bytes
- Per day: ~50 KB (assuming 100 changes)

**PULL:**
- Idle: ~1 KB per poll
- Per day: ~17 MB (5s polling = 17,280 polls)

### CPU Usage

**PUSH:**
- Work PC: 1-2% (log monitoring only)
- Pi: 5-10% (LED animations + server)

**PULL:**
- Work PC: 5-10% (server + log monitoring)
- Pi: 5-10% (polling + LED + animations)

### Latency

**PUSH:**
- Status change → Display: <1 second
- Notification delivery: 1-2 seconds

**PULL:**
- Status change → Display: 0-5 seconds
- Average latency: 2.5 seconds

---

## 📝 Configuration Files

### PUSH Architecture
```
raspberry_pi_unicorn/
├── teams_status_integrated_push.py  ← Main application
├── config_push.yaml                 ← Configuration
└── requirements_integrated.txt      ← Dependencies

powershell_service/
└── TeamsPushClient.ps1              ← Work PC client
```

### PULL Architecture
```
raspberry_pi_unicorn/
├── teams_status_integrated.py       ← Main application
├── config.yaml                      ← Configuration
└── requirements_integrated.txt      ← Dependencies

powershell_service/
└── TeamsStatusServer.ps1            ← Work PC server
```

---

## 🎓 Learning Resources

### Understanding PUSH vs PULL

**PUSH (Event-driven):**
- Source sends data when event occurs
- Receiver is always listening
- Common in webhooks, IoT, real-time systems

**PULL (Polling):**
- Receiver requests data periodically
- Source provides data on request
- Common in REST APIs, monitoring systems

### Real-World Examples

**PUSH:**
- Discord webhooks
- GitHub webhooks
- IoT device updates
- Push notifications

**PULL:**
- RSS feeds
- Weather APIs
- Stock market data
- Email (POP3/IMAP)

---

## ✅ Recommendation

**For your use case** (work PC at office, Pi at home):

**Use PUSH Architecture** ✅

Reasons:
1. Crosses network boundaries easily
2. Lower latency (instant updates)
3. Minimal network traffic
4. Simpler work PC setup
5. You're already using it!

---

**Your current PUSH setup is optimal for your requirements!** 🎉
