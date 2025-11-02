using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Devices.Enumeration;
using Windows.Storage.Streams;

namespace TeamsBLETransmitter
{
    public class RFduinoConnector : IDisposable
    {
        private BluetoothLEDevice? _device;
        private GattCharacteristic? _txCharacteristic;
        private GattCharacteristic? _rxCharacteristic;  // For receiving RSSI keepalive
        private readonly Configuration _config;
        private bool _isConnected = false;
        private DeviceWatcher? _deviceWatcher;
        private TaskCompletionSource<DeviceInformation>? _deviceFoundTcs;
        private string? _lastKnownDeviceId;
        private readonly SemaphoreSlim _reconnectLock = new SemaphoreSlim(1, 1);
        private bool _isReconnecting = false;

        // Heartbeat monitoring
        private DateTime _lastHeartbeat = DateTime.MinValue;
        private DateTime _lastHeartbeatLog = DateTime.MinValue;

        // Reconnection parameters
        private int _reconnectAttempts = 0;
        private const int MaxReconnectAttempts = 10;
        // Longer delays to give Windows BLE stack time to fully release device handles
        // AccessDenied errors happen when reconnecting too quickly
        private static readonly int[] BackoffDelaysMs = { 3000, 5000, 8000, 15000, 30000, 60000 };

        // Event fired when reconnection succeeds
        public event EventHandler? Reconnected;

        public bool IsConnected => _isConnected && _device != null && _device.ConnectionStatus == BluetoothConnectionStatus.Connected;

        public RFduinoConnector(Configuration config)
        {
            _config = config;
        }

        public async Task<bool> ConnectAsync()
        {
            try
            {
                // Try paired device first (more reliable on Windows)
                Console.WriteLine("Looking for paired RFduino device...");
                var pairedDeviceInfo = await FindPairedDeviceAsync();

                if (pairedDeviceInfo != null)
                {
                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.WriteLine($"[OK] Found paired RFduino: {pairedDeviceInfo.Name} ({pairedDeviceInfo.Id})");
                    Console.ResetColor();

                    _lastKnownDeviceId = pairedDeviceInfo.Id;
                    var connected = await ConnectToDeviceAsync(pairedDeviceInfo.Id);

                    if (connected)
                    {
                        return true;
                    }

                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("[!] Failed to connect to paired device, trying scan...");
                    Console.ResetColor();
                }

                // Fallback to scanning if no paired device or connection failed
                Console.WriteLine("Scanning for RFduino using DeviceWatcher (fast discovery)...");
                var deviceInfo = await FindDeviceWithWatcherAsync();

                if (deviceInfo == null)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("[X] RFduino not found. Make sure it's powered on and nearby.");
                    Console.WriteLine("\n💡 TIP: Try pairing the RFduino in Windows Bluetooth settings for better reliability:");
                    Console.WriteLine("   1. Open Bluetooth settings (Win+I → Bluetooth & devices)");
                    Console.WriteLine("   2. Click 'Add device' → 'Bluetooth'");
                    Console.WriteLine("   3. Select 'RFduino' when it appears");
                    Console.WriteLine("   4. Run this program again");
                    Console.ResetColor();
                    return false;
                }

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine($"[OK] Found RFduino: {deviceInfo.Name} ({deviceInfo.Id})");
                Console.ResetColor();

                // Store device ID for reconnection
                _lastKnownDeviceId = deviceInfo.Id;

                // Connect to the device
                return await ConnectToDeviceAsync(deviceInfo.Id);
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"[X] Connection error: {ex.Message}");
                Console.ResetColor();
                return false;
            }
        }

        private async Task<DeviceInformation?> FindPairedDeviceAsync()
        {
            try
            {
                // Get all paired BLE devices
                var selector = BluetoothLEDevice.GetDeviceSelectorFromPairingState(true);
                var devices = await DeviceInformation.FindAllAsync(selector);

                // Look for RFduino by name
                var rfduinoDeviceName = _config.RFduinoDeviceName ?? "RFduino";
                foreach (var device in devices)
                {
                    if (device.Name != null && device.Name.Contains(rfduinoDeviceName, StringComparison.OrdinalIgnoreCase))
                    {
                        return device;
                    }
                }

                return null;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[!] Error checking for paired devices: {ex.Message}");
                return null;
            }
        }

        private async Task<DeviceInformation?> FindDeviceWithWatcherAsync()
        {
            _deviceFoundTcs = new TaskCompletionSource<DeviceInformation>();

            var selector = BluetoothLEDevice.GetDeviceSelectorFromDeviceName(_config.RFduinoDeviceName ?? "RFduino");
            _deviceWatcher = DeviceInformation.CreateWatcher(selector);

            _deviceWatcher.Added += OnDeviceAdded;
            _deviceWatcher.EnumerationCompleted += OnEnumerationCompleted;
            _deviceWatcher.Stopped += OnWatcherStopped;

            _deviceWatcher.Start();

            // Wait up to 15 seconds for device to be found
            var timeoutTask = Task.Delay(15000);
            var completedTask = await Task.WhenAny(_deviceFoundTcs.Task, timeoutTask);

            // Stop watcher
            if (_deviceWatcher.Status == DeviceWatcherStatus.Started ||
                _deviceWatcher.Status == DeviceWatcherStatus.EnumerationCompleted)
            {
                _deviceWatcher.Stop();
            }

            // Cleanup event handlers
            _deviceWatcher.Added -= OnDeviceAdded;
            _deviceWatcher.EnumerationCompleted -= OnEnumerationCompleted;
            _deviceWatcher.Stopped -= OnWatcherStopped;

            if (completedTask == timeoutTask)
            {
                return null; // Timeout
            }

            return await _deviceFoundTcs.Task;
        }

        private void OnDeviceAdded(DeviceWatcher sender, DeviceInformation deviceInfo)
        {
            // Found a matching device - complete the task
            _deviceFoundTcs?.TrySetResult(deviceInfo);
        }

        private void OnEnumerationCompleted(DeviceWatcher sender, object args)
        {
            // Enumeration completed without finding device
            if (_deviceFoundTcs?.Task.IsCompleted == false)
            {
                _deviceFoundTcs.TrySetResult(null!);
            }
        }

        private void OnWatcherStopped(DeviceWatcher sender, object args)
        {
            // Watcher stopped
        }

        private async Task<bool> ConnectToDeviceAsync(string deviceId)
        {
            try
            {
                Console.WriteLine($"\nConnecting to RFduino at {deviceId}...");

                // Add timeout for connection attempt
                var connectionTask = BluetoothLEDevice.FromIdAsync(deviceId).AsTask();
                var timeoutTask = Task.Delay(10000); // 10 second timeout
                var completedTask = await Task.WhenAny(connectionTask, timeoutTask);

                if (completedTask == timeoutTask)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("[X] Connection timeout (10 seconds)");
                    Console.ResetColor();
                    return false;
                }

                _device = await connectionTask;

                if (_device == null)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("[X] Failed to connect to RFduino");
                    Console.ResetColor();
                    return false;
                }

                Console.WriteLine($"Connection status: {_device.ConnectionStatus}");

                // Monitor connection status changes
                _device.ConnectionStatusChanged += OnConnectionStatusChanged;

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("[OK] Connected to RFduino");
                Console.ResetColor();

                // Wait for connection to stabilize before discovering services
                // This is critical for Simblee/RFduino devices
                // Longer delay helps Windows BLE stack and Simblee negotiate connection parameters
                Console.WriteLine("Waiting for connection to stabilize...");

                // Try multiple short checks instead of one long wait
                // This helps detect connection issues earlier and retries if needed
                bool stableConnection = false;
                for (int i = 0; i < 4; i++)
                {
                    await Task.Delay(500);  // Check every 500ms, 4 times = 2 seconds total

                    if (_device.ConnectionStatus == BluetoothConnectionStatus.Connected)
                    {
                        stableConnection = true;
                    }
                    else
                    {
                        Console.ForegroundColor = ConsoleColor.Yellow;
                        Console.WriteLine($"[!] Connection unstable at check {i+1}/4, status: {_device.ConnectionStatus}");
                        Console.ResetColor();
                        stableConnection = false;
                        break;
                    }
                }

                if (!stableConnection)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("[X] Connection lost during stabilization");
                    Console.ResetColor();
                    return false;
                }

                // Discover services and characteristics
                Console.WriteLine("\nDiscovering BLE services...");
                var serviceDiscoveryTask = _device.GetGattServicesAsync(BluetoothCacheMode.Uncached).AsTask();
                var serviceTimeoutTask = Task.Delay(5000); // 5 second timeout for service discovery
                var serviceCompletedTask = await Task.WhenAny(serviceDiscoveryTask, serviceTimeoutTask);

                if (serviceCompletedTask == serviceTimeoutTask)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("[X] Service discovery timeout (5 seconds)");
                    Console.ResetColor();
                    return false;
                }

                var result = await serviceDiscoveryTask;

                Console.WriteLine($"Service discovery status: {result.Status}");
                Console.WriteLine($"Found {result.Services?.Count ?? 0} services");

                if (result.Status != GattCommunicationStatus.Success)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine($"[X] Failed to discover GATT services: {result.Status}");

                    if (result.ProtocolError.HasValue)
                    {
                        Console.WriteLine($"[X] Protocol error: {result.ProtocolError.Value}");
                    }

                    Console.ResetColor();
                    Console.WriteLine("\nTroubleshooting:");
                    Console.WriteLine("  1. Try unpairing and re-pairing the RFduino in Windows Bluetooth settings");
                    Console.WriteLine("  2. Restart the RFduino (power cycle)");
                    Console.WriteLine("  3. Restart Windows Bluetooth service: net stop bthserv && net start bthserv");
                    Console.WriteLine("  4. Run as Administrator if needed");
                    return false;
                }

                // Find the RFduino custom service
                // UUID 2d30c082-f39f-4ce6-923f-3484ea480596 (or short form 2220)
                GattCharacteristic? writableChar = null;
                GattCharacteristic? readableChar = null;

                Console.WriteLine("Discovering characteristics in each service...");
                foreach (var service in result.Services)
                {
                    Console.WriteLine($"  Service: {service.Uuid}");

                    // Add small delay before characteristic discovery to help with Simblee timing
                    await Task.Delay(100);

                    var charResult = await service.GetCharacteristicsAsync(BluetoothCacheMode.Uncached);

                    if (charResult.Status == GattCommunicationStatus.Success)
                    {
                        Console.WriteLine($"    Found {charResult.Characteristics?.Count ?? 0} characteristics");
                        foreach (var characteristic in charResult.Characteristics)
                        {
                            var props = characteristic.CharacteristicProperties;
                            Console.WriteLine($"    Characteristic: {characteristic.Uuid}");
                            Console.WriteLine($"      Properties: {props}");

                            var uuidStr = characteristic.Uuid.ToString().ToLower();
                            var serviceUuidStr = service.Uuid.ToString().ToLower();

                            // Look for readable characteristic for RSSI monitoring (2d30c082 - TX from device)
                            if (props.HasFlag(GattCharacteristicProperties.Notify) &&
                                uuidStr.StartsWith("2d30c082"))
                            {
                                readableChar = characteristic;
                                Console.WriteLine($"    ★ Found RFduino TX characteristic (device → host) for RSSI");
                            }

                            // Look for writable characteristic (WriteWithoutResponse or Write)
                            if (props.HasFlag(GattCharacteristicProperties.WriteWithoutResponse) ||
                                props.HasFlag(GattCharacteristicProperties.Write))
                            {
                                // Skip standard BLE characteristics (Generic Access, Device Info, etc.)
                                if (uuidStr.Contains("00002a00") || // Device Name (read-only)
                                    uuidStr.Contains("00002a01") || // Appearance
                                    uuidStr.Contains("00002a04") || // Peripheral Preferred Connection Parameters
                                    uuidStr.Contains("0000180a"))   // Device Information Service
                                {
                                    Console.WriteLine($"      Skipping standard BLE characteristic");
                                    continue;
                                }

                                Console.WriteLine($"    ✓ Found writable custom characteristic: {characteristic.Uuid}");

                                // Select the correct RFduino RX characteristic (2d30c083)
                                // This is where the Simblee receives data from the host
                                // 2d30c082: TX (device sends to host - Read/Notify)
                                // 2d30c083: RX (host sends to device - Write) ← WE WANT THIS ONE
                                // 2d30c084: Disconnect characteristic (not for data)

                                // Prefer 2d30c083 (RX) above all else
                                if (uuidStr.StartsWith("2d30c083"))
                                {
                                    writableChar = characteristic;
                                    Console.WriteLine($"      ★ Selected RFduino RX characteristic (host → device)");
                                }
                                // Otherwise, use any writable in fe84 service if we don't have anything yet
                                // but 2d30c083 will override this if found later
                                else if (writableChar == null && serviceUuidStr.Contains("fe84"))
                                {
                                    writableChar = characteristic;
                                }
                            }
                        }
                    }
                    else
                    {
                        Console.WriteLine($"    ⚠ Failed to get characteristics: {charResult.Status}");
                    }
                }

                if (writableChar == null)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("[X] No writable characteristic found");
                    Console.ResetColor();
                    return false;
                }

                _txCharacteristic = writableChar;
                _rxCharacteristic = readableChar;
                _isConnected = true;
                _reconnectAttempts = 0; // Reset reconnection counter on successful connect

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine($"[OK] Using TX characteristic: {_txCharacteristic.Uuid}");
                if (_rxCharacteristic != null)
                {
                    Console.WriteLine($"[OK] Using RX characteristic for heartbeat: {_rxCharacteristic.Uuid}");

                    // Subscribe to heartbeat notifications from device
                    try
                    {
                        var cccdResult = await _rxCharacteristic.WriteClientCharacteristicConfigurationDescriptorAsync(
                            GattClientCharacteristicConfigurationDescriptorValue.Notify);

                        if (cccdResult == GattCommunicationStatus.Success)
                        {
                            _rxCharacteristic.ValueChanged += OnHeartbeatReceived;
                            Console.WriteLine("[OK] Subscribed to heartbeat from device");
                        }
                        else
                        {
                            Console.WriteLine($"[!] Failed to subscribe to heartbeat: {cccdResult}");
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"[!] Heartbeat subscription error: {ex.Message}");
                    }
                }
                Console.ResetColor();

                return true;
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"[X] Connection error: {ex.Message}");
                Console.ResetColor();
                return false;
            }
        }

        private void OnConnectionStatusChanged(BluetoothLEDevice sender, object args)
        {
            if (sender.ConnectionStatus == BluetoothConnectionStatus.Disconnected)
            {
                // Only log and trigger reconnection if not already reconnecting
                // This prevents reconnection storms from rapid connect/disconnect events
                if (!_isReconnecting && _isConnected)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine($"\n[!] RFduino disconnected at {DateTime.Now:HH:mm:ss}");
                    Console.ResetColor();
                    _isConnected = false;

                    // Trigger reconnection in background
                    _ = Task.Run(() => ReconnectAsync());
                }
            }
            else if (sender.ConnectionStatus == BluetoothConnectionStatus.Connected)
            {
                // Only log if we're not in the middle of a reconnection attempt
                if (!_isReconnecting)
                {
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine($"[OK] RFduino connected at {DateTime.Now:HH:mm:ss}");
                    Console.ResetColor();
                }
                _isConnected = true;
            }
        }

        public async Task<bool> ReconnectAsync()
        {
            // Prevent multiple simultaneous reconnection attempts
            if (!await _reconnectLock.WaitAsync(0))
            {
                return false; // Already reconnecting
            }

            try
            {
                if (_isReconnecting)
                {
                    return false;
                }

                _isReconnecting = true;

                while (_reconnectAttempts < MaxReconnectAttempts)
                {
                    _reconnectAttempts++;

                    // Calculate backoff delay
                    var delayIndex = Math.Min(_reconnectAttempts - 1, BackoffDelaysMs.Length - 1);
                    var delayMs = BackoffDelaysMs[delayIndex];

                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.WriteLine($"[→] Reconnection attempt {_reconnectAttempts}/{MaxReconnectAttempts} in {delayMs / 1000}s...");
                    Console.ResetColor();

                    // Dispose old connection FIRST, before delay
                    // This gives Windows maximum time to release handles
                    CleanupConnection();

                    await Task.Delay(delayMs);

                    // Try to reconnect using cached device ID if available
                    bool success = false;
                    if (!string.IsNullOrEmpty(_lastKnownDeviceId))
                    {
                        success = await ConnectToDeviceAsync(_lastKnownDeviceId);
                    }

                    // If cached connection failed, try full scan
                    if (!success)
                    {
                        Console.WriteLine("[→] Cached connection failed, performing full scan...");
                        success = await ConnectAsync();
                    }

                    if (success)
                    {
                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.WriteLine($"[OK] Reconnected successfully after {_reconnectAttempts} attempts");
                        Console.ResetColor();
                        _isReconnecting = false;

                        // Fire reconnection event so service can resend current status
                        Reconnected?.Invoke(this, EventArgs.Empty);

                        return true;
                    }
                }

                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"[X] Failed to reconnect after {MaxReconnectAttempts} attempts");
                Console.ResetColor();
                _isReconnecting = false;
                return false;
            }
            finally
            {
                _reconnectLock.Release();
            }
        }

        private void OnHeartbeatReceived(GattCharacteristic sender, GattValueChangedEventArgs args)
        {
            try
            {
                var reader = DataReader.FromBuffer(args.CharacteristicValue);

                // Check if this is a heartbeat packet (0xFE marker)
                if (reader.UnconsumedBufferLength >= 1)
                {
                    byte marker = reader.ReadByte();
                    if (marker == 0xFE)
                    {
                        _lastHeartbeat = DateTime.Now;

                        // Log heartbeat periodically (every 30 seconds) to show connection is alive
                        var timeSinceLastLog = DateTime.Now - _lastHeartbeatLog;
                        if (timeSinceLastLog.TotalSeconds > 30 || _lastHeartbeatLog == DateTime.MinValue)
                        {
                            Console.ForegroundColor = ConsoleColor.DarkGray;
                            Console.WriteLine($"[💓] Heartbeat received - connection healthy");
                            Console.ResetColor();
                            _lastHeartbeatLog = DateTime.Now;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[!] Heartbeat processing error: {ex.Message}");
            }
        }

        private void CleanupConnection()
        {
            if (_device != null)
            {
                try
                {
                    _device.ConnectionStatusChanged -= OnConnectionStatusChanged;

                    // Unsubscribe from heartbeat notifications
                    if (_rxCharacteristic != null)
                    {
                        _rxCharacteristic.ValueChanged -= OnHeartbeatReceived;
                    }

                    // Force Windows to release all GATT service/characteristic handles
                    // This is critical to avoid AccessDenied errors on reconnection
                    var services = _device.GattServices;
                    foreach (var service in services)
                    {
                        service.Dispose();
                    }

                    _device.Dispose();
                    _device = null;
                }
                catch
                {
                    // Ignore cleanup errors
                }
            }
            _txCharacteristic = null;
            _rxCharacteristic = null;
            _isConnected = false;

            // Give Windows BLE stack time to fully release device handles
            // 2 seconds allows Windows to properly invalidate cached connection state
            // Shorter delays cause AccessDenied errors on reconnection
            Thread.Sleep(2000);
        }

        public async Task<bool> SendStatusAsync(TeamsStatus status)
        {
            // Check if we need to reconnect
            if (!IsConnected)
            {
                if (!_isReconnecting)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("[!] Not connected to RFduino, attempting to reconnect...");
                    Console.ResetColor();
                    _ = Task.Run(() => ReconnectAsync());
                }
                return false;
            }

            try
            {
                // Convert status to byte (matching Python implementation)
                byte statusCode = (byte)status;

                Console.WriteLine($"[→] Sending status {status} (code: {statusCode}) to characteristic {_txCharacteristic!.Uuid}");

                // Create data buffer
                var writer = new DataWriter();
                writer.WriteByte(statusCode);

                // Send data
                var writeResult = await _txCharacteristic!.WriteValueAsync(
                    writer.DetachBuffer(),
                    GattWriteOption.WriteWithoutResponse
                );

                if (writeResult != GattCommunicationStatus.Success)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine($"[X] Failed to send status: {writeResult}");
                    Console.ResetColor();
                    _isConnected = false;
                    return false;
                }

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine($"[✓] Sent status {status} successfully");
                Console.ResetColor();

                return true;
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"[X] Send error: {ex.Message}");
                Console.ResetColor();
                _isConnected = false;

                // Trigger reconnection
                if (!_isReconnecting)
                {
                    _ = Task.Run(() => ReconnectAsync());
                }

                return false;
            }
        }

        public void Dispose()
        {
            CleanupConnection();
            _reconnectLock.Dispose();
        }
    }
}
