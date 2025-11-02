using System;
using System.Threading;
using System.Threading.Tasks;

namespace TeamsBLETransmitter
{
    public class TeamsStatusService : IDisposable
    {
        private readonly Configuration _config;
        private readonly TeamsLogMonitor _logMonitor;
        private readonly RFduinoConnector _rfduino;
        private TeamsStatus _lastSentStatus = TeamsStatus.Unknown;
        private DateTime _lastSendTime = DateTime.MinValue;

        // Keepalive interval to prevent BLE supervision timeout
        // Windows BLE supervision timeout is ~50-60 seconds
        // Send keepalive every 20 seconds to stay well under the timeout
        private static readonly TimeSpan KeepaliveInterval = TimeSpan.FromSeconds(20);

        public TeamsStatusService(Configuration config)
        {
            _config = config;
            _logMonitor = new TeamsLogMonitor(config.TeamsLogPath, config.VerboseLogging);
            _rfduino = new RFduinoConnector(config);

            // Subscribe to reconnection event to resend current status
            _rfduino.Reconnected += OnRFduinoReconnected;
        }

        public async Task RunAsync(CancellationToken cancellationToken)
        {
            // Connect to RFduino
            var connected = await _rfduino.ConnectAsync();
            if (!connected)
            {
                throw new Exception("Failed to connect to RFduino");
            }

            Console.WriteLine("\nConfiguration:");
            Console.WriteLine($"  Check Interval: {_config.CheckIntervalSeconds} seconds");
            Console.WriteLine($"  Teams Log Path: {_config.TeamsLogPath}");

            Console.WriteLine("\nMonitoring Teams status...\n");

            // Main monitoring loop
            while (!cancellationToken.IsCancellationRequested)
            {
                try
                {
                    // Get current Teams status
                    var currentStatus = _logMonitor.GetCurrentStatus();

                    // Calculate time since last send
                    var timeSinceLastSend = DateTime.Now - _lastSendTime;
                    var needsKeepalive = timeSinceLastSend >= KeepaliveInterval &&
                                        _lastSentStatus != TeamsStatus.Unknown &&
                                        _rfduino.IsConnected;

                    // Send if status changed OR keepalive needed
                    if ((currentStatus != _lastSentStatus && currentStatus != TeamsStatus.Unknown) || needsKeepalive)
                    {
                        var statusToSend = currentStatus != TeamsStatus.Unknown ? currentStatus : _lastSentStatus;
                        var success = await _rfduino.SendStatusAsync(statusToSend);

                        if (success)
                        {
                            _lastSentStatus = statusToSend;
                            _lastSendTime = DateTime.Now;

                            // Display status change or keepalive
                            var timestamp = DateTime.Now.ToString("HH:mm:ss");

                            if (needsKeepalive && currentStatus == _lastSentStatus)
                            {
                                Console.ForegroundColor = ConsoleColor.DarkGray;
                                Console.WriteLine($"[{timestamp}] Keepalive: {statusToSend.ToDisplayString()} (prevents timeout)");
                                Console.ResetColor();
                            }
                            else
                            {
                                Console.ForegroundColor = statusToSend.ToConsoleColor();
                                Console.WriteLine($"[{timestamp}] Sent: {statusToSend.ToDisplayString()} (code: {(int)statusToSend})");
                                Console.ResetColor();
                            }
                        }
                    }

                    // Wait for next check interval
                    await Task.Delay(
                        TimeSpan.FromSeconds(_config.CheckIntervalSeconds),
                        cancellationToken
                    );
                }
                catch (OperationCanceledException)
                {
                    // Normal cancellation, exit gracefully
                    break;
                }
                catch (Exception ex)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine($"[!] Error in monitoring loop: {ex.Message}");
                    Console.ResetColor();

                    // Wait a bit before retrying
                    await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
                }
            }
        }

        private async void OnRFduinoReconnected(object? sender, EventArgs e)
        {
            // Resend the last sent status to restore LED color after reconnection
            if (_lastSentStatus != TeamsStatus.Unknown)
            {
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine($"[→] Resending last status after reconnection: {_lastSentStatus.ToDisplayString()}");
                Console.ResetColor();

                // Force resend even if status hasn't changed
                var success = await _rfduino.SendStatusAsync(_lastSentStatus);
                if (success)
                {
                    _lastSendTime = DateTime.Now; // Reset keepalive timer

                    var timestamp = DateTime.Now.ToString("HH:mm:ss");
                    Console.ForegroundColor = _lastSentStatus.ToConsoleColor();
                    Console.WriteLine($"[{timestamp}] Restored: {_lastSentStatus.ToDisplayString()} (code: {(int)_lastSentStatus})");
                    Console.ResetColor();
                }
            }
        }

        public void Dispose()
        {
            _rfduino?.Dispose();
        }
    }
}
