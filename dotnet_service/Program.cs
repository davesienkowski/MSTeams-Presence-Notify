using System;
using System.Threading;
using System.Threading.Tasks;

namespace TeamsBLETransmitter
{
    class Program
    {
        static async Task Main(string[] args)
        {
            // Check for scan mode
            if (args.Length > 0 && (args[0] == "--scan" || args[0] == "/scan"))
            {
                await BLEScanner.ScanForAllDevices();
                Console.WriteLine("\nPress any key to exit...");
                Console.ReadKey();
                return;
            }

            Console.WriteLine("========================================");
            Console.WriteLine("Teams Status BLE Transmitter for RFduino");
            Console.WriteLine("========================================\n");

            // Parse command line arguments
            var config = new Configuration(args);

            // Create and start the service
            using var cts = new CancellationTokenSource();
            var service = new TeamsStatusService(config);

            // Handle Ctrl+C gracefully
            Console.CancelKeyPress += (sender, e) =>
            {
                e.Cancel = true;
                Console.WriteLine("\n\nShutting down...");
                cts.Cancel();
            };

            try
            {
                await service.RunAsync(cts.Token);
            }
            catch (OperationCanceledException)
            {
                Console.WriteLine("Service stopped.");
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"\n[X] Fatal error: {ex.Message}");
                Console.ResetColor();
                Environment.Exit(1);
            }
        }
    }
}
