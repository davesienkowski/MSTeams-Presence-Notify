using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace TeamsWiFiTransmitter
{
    /// <summary>
    /// Teams Status WiFi Transmitter for ESP32
    /// Much simpler than BLE - just HTTP POST!
    /// </summary>
    class Program
    {
        private static readonly HttpClient httpClient = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(5)
        };

        static async Task Main(string[] args)
        {
            Console.WriteLine("========================================");
            Console.WriteLine("Teams Status WiFi Transmitter for ESP32");
            Console.WriteLine("========================================\n");

            // Get ESP32 address from command line or use default
            string esp32Address = args.Length > 0 ? args[0] : "teams-status.local";

            // Validate address format
            if (!esp32Address.StartsWith("http://") && !esp32Address.StartsWith("https://"))
            {
                esp32Address = $"http://{esp32Address}";
            }

            Console.WriteLine($"ESP32 Address: {esp32Address}");
            Console.WriteLine($"Monitoring Teams status every 5 seconds...\n");

            // Test connection first
            if (!await TestConnection(esp32Address))
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("\n[ERROR] Cannot connect to ESP32!");
                Console.WriteLine("Make sure:");
                Console.WriteLine("  1. ESP32 is powered on and connected to WiFi");
                Console.WriteLine("  2. ESP32 IP address is correct");
                Console.WriteLine("  3. Both devices are on the same network");
                Console.ResetColor();
                Console.WriteLine("\nPress any key to exit...");
                Console.ReadKey();
                return;
            }

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("[OK] Connected to ESP32!\n");
            Console.ResetColor();

            // Create cancellation token for Ctrl+C
            using var cts = new CancellationTokenSource();
            Console.CancelKeyPress += (sender, e) =>
            {
                e.Cancel = true;
                Console.WriteLine("\n\nShutting down...");
                cts.Cancel();
            };

            // Create Teams monitor
            var monitor = new TeamsLogMonitor();
            TeamsStatus? lastStatus = null;

            // Main loop
            while (!cts.Token.IsCancellationRequested)
            {
                try
                {
                    var currentStatus = monitor.GetCurrentStatus();

                    // Only send if status changed
                    if (currentStatus != lastStatus)
                    {
                        bool success = await SendStatus(esp32Address, currentStatus);

                        if (success)
                        {
                            var color = GetStatusColor(currentStatus);
                            Console.ForegroundColor = color;
                            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Status: {currentStatus}");
                            Console.ResetColor();
                        }

                        lastStatus = currentStatus;
                    }

                    await Task.Delay(5000, cts.Token);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine($"[WARN] Error: {ex.Message}");
                    Console.ResetColor();
                    await Task.Delay(5000, cts.Token);
                }
            }

            Console.WriteLine("Service stopped.");
        }

        private static async Task<bool> TestConnection(string esp32Address)
        {
            try
            {
                var response = await httpClient.GetAsync($"{esp32Address}/api/health");
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        private static async Task<bool> SendStatus(string esp32Address, TeamsStatus status)
        {
            try
            {
                var payload = new { status = (int)status };
                var response = await httpClient.PostAsJsonAsync($"{esp32Address}/status", payload);
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine($"[WARN] Failed to send status: {ex.Message}");
                Console.ResetColor();
                return false;
            }
        }

        private static ConsoleColor GetStatusColor(TeamsStatus status)
        {
            return status switch
            {
                TeamsStatus.Available => ConsoleColor.Green,
                TeamsStatus.Busy => ConsoleColor.Red,
                TeamsStatus.Presenting => ConsoleColor.Red,
                TeamsStatus.InAMeeting => ConsoleColor.Red,
                TeamsStatus.InACall => ConsoleColor.Red,
                TeamsStatus.Away => ConsoleColor.Yellow,
                TeamsStatus.BeRightBack => ConsoleColor.Yellow,
                TeamsStatus.DoNotDisturb => ConsoleColor.Magenta,
                TeamsStatus.Focusing => ConsoleColor.Magenta,
                TeamsStatus.Offline => ConsoleColor.DarkGray,
                _ => ConsoleColor.White
            };
        }
    }

    /// <summary>
    /// Teams status codes matching ESP32 firmware
    /// </summary>
    public enum TeamsStatus
    {
        Available = 0,
        Busy = 1,
        Away = 2,
        BeRightBack = 3,
        DoNotDisturb = 4,
        Focusing = 5,
        Presenting = 6,
        InAMeeting = 7,
        InACall = 8,
        Offline = 9,
        Unknown = 10
    }

    /// <summary>
    /// Monitors Teams log files for status changes
    /// Based on the existing implementation
    /// </summary>
    public class TeamsLogMonitor
    {
        private readonly string teamsLogPath;
        private DateTime lastRead = DateTime.MinValue;

        public TeamsLogMonitor()
        {
            // Find Teams log directory
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);

            // Try New Teams first (Microsoft Teams 2.0)
            var newTeamsPath = Path.Combine(appData, "Microsoft", "Teams", "logs.txt");
            if (File.Exists(newTeamsPath))
            {
                teamsLogPath = newTeamsPath;
                Console.WriteLine($"[OK] Found New Teams logs: {newTeamsPath}");
                return;
            }

            // Try Classic Teams
            var classicTeamsPath = Path.Combine(appData, "Microsoft", "Teams", "logs", "MSTeams.log");
            if (File.Exists(classicTeamsPath))
            {
                teamsLogPath = classicTeamsPath;
                Console.WriteLine($"[OK] Found Classic Teams logs: {classicTeamsPath}");
                return;
            }

            // Log file not found
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("[ERROR] Teams log file not found!");
            Console.WriteLine("Make sure Microsoft Teams is installed and running.");
            Console.ResetColor();
            teamsLogPath = "";
        }

        public TeamsStatus GetCurrentStatus()
        {
            if (string.IsNullOrEmpty(teamsLogPath) || !File.Exists(teamsLogPath))
            {
                return TeamsStatus.Unknown;
            }

            try
            {
                // Read last 50KB of log file (most recent entries)
                using var fs = new FileStream(teamsLogPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                var startPos = Math.Max(0, fs.Length - 50000);
                fs.Seek(startPos, SeekOrigin.Begin);

                using var reader = new StreamReader(fs);
                var content = reader.ReadToEnd();

                // Parse status from log patterns
                return ParseStatus(content);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[WARN] Error reading log: {ex.Message}");
                return TeamsStatus.Unknown;
            }
        }

        private TeamsStatus ParseStatus(string logContent)
        {
            // Pattern matching based on existing implementation
            // Look for status indicators in reverse order (most recent first)

            if (logContent.Contains("\"NewActivity\":\"InACall\""))
                return TeamsStatus.InACall;

            if (logContent.Contains("\"NewActivity\":\"InAMeeting\""))
                return TeamsStatus.InAMeeting;

            if (logContent.Contains("\"NewActivity\":\"Presenting\""))
                return TeamsStatus.Presenting;

            if (logContent.Contains("\"NewActivity\":\"DoNotDisturb\""))
                return TeamsStatus.DoNotDisturb;

            if (logContent.Contains("\"NewActivity\":\"Focusing\""))
                return TeamsStatus.Focusing;

            if (logContent.Contains("\"NewActivity\":\"Busy\""))
                return TeamsStatus.Busy;

            if (logContent.Contains("\"NewActivity\":\"BeRightBack\""))
                return TeamsStatus.BeRightBack;

            if (logContent.Contains("\"NewActivity\":\"Away\""))
                return TeamsStatus.Away;

            if (logContent.Contains("\"NewActivity\":\"Available\""))
                return TeamsStatus.Available;

            if (logContent.Contains("\"NewActivity\":\"Offline\""))
                return TeamsStatus.Offline;

            return TeamsStatus.Unknown;
        }
    }
}
