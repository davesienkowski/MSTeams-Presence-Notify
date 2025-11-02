# BLE Connection Stability Analysis & Improvements

## Problem Summary

The Simblee RFduino connection to Windows PC shows intermittent disconnections:
- Initial connection works but device disconnects after ~30 seconds to 6 minutes
- Reconnection attempts report "Connected" but immediately show "Disconnected"
- "Connection lost during stabilization" errors
- Eventually reconnects after multiple attempts

## Root Cause Analysis

Based on logs and research, the primary issues are:

### 1. **Windows BLE Stack Quirks**
- Windows BLE API can report `ConnectionStatus.Connected` even when the physical connection is unstable
- Windows requires longer stabilization periods for Simblee/RFduino devices than other BLE peripherals
- Cached connection state can become stale, causing "Connected→Disconnected" transitions

### 2. **Connection Parameter Negotiation**
- BLE connection parameters (interval, latency, supervision timeout) must be properly negotiated
- Default supervision timeout may be too short for packet loss tolerance
- Formula: `supervision_timeout > (1 + slave_latency) * 2 * conn_interval_max`
- With 60ms max interval, minimum timeout should be 120ms, but 4-6 seconds is recommended

### 3. **Lack of Connection Health Monitoring**
- No visibility into signal strength (RSSI) to diagnose weak connections
- No keepalive mechanism to maintain connection during idle periods
- Difficult to distinguish between signal issues vs. stack issues

## Implemented Improvements

### Firmware Changes (TeamsStatus_Simblee.ino)

#### 1. **Keepalive Heartbeat Mechanism**
```cpp
const unsigned long KEEPALIVE_INTERVAL = 5000;  // 5 seconds

void sendHeartbeat() {
    // Send simple heartbeat packet to keep connection alive
    // 0xFE is a reserved value that won't conflict with status codes (0-10)
    uint8_t heartbeat = 0xFE;
    SimbleeBLE.send((char*)&heartbeat, 1);
}
```
- Sends heartbeat every 5 seconds to maintain connection
- Uses 0xFE marker to distinguish from status codes (0-10)
- Simple 1-byte packet minimizes overhead
- **Note**: Simblee library doesn't expose RSSI for host-to-device monitoring, so we use a simple heartbeat instead

#### 2. **Connection Parameter Documentation**
```cpp
// Min: 30ms, Max: 60ms (more conservative for Windows compatibility)
// Slave latency: 0 (respond to every connection event for reliability)
// Supervision timeout: 4000ms (4 seconds - must be > 2 * maxInterval)
SimbleeBLE.updateConnInterval(30, 60);
```
- Documents recommended parameters for Windows compatibility
- Note: Simblee library may not expose supervision timeout directly
- Default is typically 4-6 seconds which should be adequate

### C# Changes (RFduinoConnector.cs)

#### 1. **Heartbeat Reception Support**
```csharp
private GattCharacteristic? _rxCharacteristic;  // For receiving heartbeat keepalive
private DateTime _lastHeartbeat = DateTime.MinValue;
private DateTime _lastHeartbeatLog = DateTime.MinValue;

private void OnHeartbeatReceived(GattCharacteristic sender, GattValueChangedEventArgs args) {
    byte marker = reader.ReadByte();
    if (marker == 0xFE) {
        _lastHeartbeat = DateTime.Now;

        // Log heartbeat periodically (every 30 seconds) to show connection is alive
        var timeSinceLastLog = DateTime.Now - _lastHeartbeatLog;
        if (timeSinceLastLog.TotalSeconds > 30 || _lastHeartbeatLog == DateTime.MinValue) {
            Console.WriteLine($"[💓] Heartbeat received - connection healthy");
            _lastHeartbeatLog = DateTime.Now;
        }
    }
}
```
- Subscribes to TX characteristic (2d30c082) for device→host notifications
- Logs heartbeat reception every 30 seconds
- Provides connection health monitoring

#### 2. **Improved Connection Stabilization**
```csharp
// Try multiple short checks instead of one long wait
bool stableConnection = false;
for (int i = 0; i < 4; i++)
{
    await Task.Delay(500);  // Check every 500ms, 4 times = 2 seconds total

    if (_device.ConnectionStatus == BluetoothConnectionStatus.Connected)
        stableConnection = true;
    else {
        Console.WriteLine($"[!] Connection unstable at check {i+1}/4");
        stableConnection = false;
        break;
    }
}
```
- Changed from single 2-second wait to 4x 500ms checks
- Detects connection issues earlier
- Provides better diagnostics during stabilization

#### 3. **RX Characteristic Discovery**
```csharp
// Look for readable characteristic for heartbeat monitoring (2d30c082 - TX from device)
if (props.HasFlag(GattCharacteristicProperties.Notify) &&
    uuidStr.StartsWith("2d30c082"))
{
    readableChar = characteristic;
    Console.WriteLine($"    ★ Found RFduino TX characteristic (device → host) for heartbeat");
}
```
- Discovers 2d30c082 (TX) in addition to 2d30c083 (RX)
- Subscribes to notifications for keepalive heartbeat data

## Expected Results

### With Current Firmware (No Keepalive)
- ❌ Disconnections may still occur after ~30 seconds to 6 minutes
- ❌ Idle connections may timeout

### With New Firmware (Keepalive Heartbeat)
- ✅ Heartbeat every 5 seconds maintains connection activity
- ✅ Improved stabilization checks catch issues earlier
- ✅ Connection health monitoring via periodic heartbeat logs
- ⚠️ May still experience Windows BLE stack issues (inherent to Windows)
- ℹ️ No RSSI monitoring available (Simblee limitation)

## Testing Steps

1. **Upload New Firmware**
   - Open TeamsStatus_Simblee.ino in Arduino IDE
   - Upload to Simblee/RFduino device
   - Verify LED animations work (startup fade + green blinks)

2. **Rebuild C# Application** (or use pre-built executable)
   ```bash
   cd dotnet_service
   dotnet build -c Release
   dotnet publish -c Release --self-contained -r win-x64
   ```

3. **Test Connection**
   - Run TeamsBLETransmitter.exe
   - Watch for heartbeat subscription message: `[OK] Subscribed to heartbeat from device`
   - Monitor for heartbeat logs: `[💓] Heartbeat received - connection healthy` (every 30 seconds)
   - Observe connection stability over 10+ minutes

4. **Analyze Results**
   - If disconnections still occur, note:
     - Time since last heartbeat before disconnect
     - Any Windows BLE errors in Event Viewer
     - Connection duration patterns

## Additional Troubleshooting Options

If issues persist after implementing keepalive:

### Option 1: Increase Heartbeat Frequency
```cpp
const unsigned long KEEPALIVE_INTERVAL = 2000;  // Try 2 seconds instead of 5
```
**Trade-off**: More frequent keepalive = higher power usage but more stable connection

### Option 2: Try More Conservative Connection Parameters
```cpp
SimbleeBLE.updateConnInterval(50, 100);  // Slower but potentially more stable
```

### Option 3: Physical Improvements
- Move Simblee closer to PC (reduce distance)
- Remove obstacles between devices
- Check for USB 3.0 interference (try USB 2.0 port)
- Ensure good USB power supply (not a hub)

### Option 4: Windows BLE Stack Reset
```powershell
# Run as Administrator
net stop bthserv
net start bthserv

# Or restart Bluetooth adapter in Device Manager
```

## Protocol Reference

### BLE Characteristics (Service: 0000fe84)
| UUID | Direction | Purpose |
|------|-----------|---------|
| 2d30c082 | Device→Host | TX (Notify) - RSSI keepalive |
| 2d30c083 | Host→Device | RX (Write) - Status updates |
| 2d30c084 | Both | Disconnect control |

### Data Packet Formats

**Status Update (Host→Device):**
```
[status_code]  // 1 byte: 0-10
```

**Heartbeat Keepalive (Device→Host):**
```
[0xFE]  // 1 byte: heartbeat marker
```

## References

- [Punch Through: Managing BLE Connections](https://punchthrough.com/manage-ble-connection/)
- [Silicon Labs: BLE Connection Parameters](https://docs.silabs.com/bluetooth/latest/miscellaneous/mobile/selecting-suitable-connection-parameters-for-apple-devices)
- [RFduino/Simblee Library Documentation](https://github.com/RFduino/RFduino)

## Conclusion

The connection instability is likely a combination of:
1. **Windows BLE stack quirks** (major factor - inherent to Windows)
2. **Lack of keepalive mechanism** (now addressed with heartbeat)
3. **Connection parameter negotiation issues** (now documented and optimized)

The new firmware and C# code provide:
- Active keepalive (5-second heartbeat) to prevent timeout disconnections
- Connection health monitoring via heartbeat reception logs
- Better connection validation during stabilization (4x 500ms checks)

**Note on RSSI**: The Simblee library doesn't expose the RSSI value that the host sees from the device, so we can't implement signal strength monitoring in firmware. The host's Windows BLE stack does measure RSSI, but it's not easily accessible from the C# Windows.Devices.Bluetooth API.

However, Windows BLE stack issues may still cause occasional disconnections that are beyond firmware control. The improvements should reduce frequency and provide better diagnostics when issues occur.
