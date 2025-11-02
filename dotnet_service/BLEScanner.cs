using System;
using System.Threading.Tasks;
using Windows.Devices.Bluetooth;
using Windows.Devices.Enumeration;

namespace TeamsBLETransmitter
{
    public class BLEScanner
    {
        public static async Task ScanForAllDevices()
        {
            Console.WriteLine("===========================================");
            Console.WriteLine("BLE Device Scanner - Finding ALL Devices");
            Console.WriteLine("===========================================\n");
            Console.WriteLine("Scanning for 15 seconds...\n");

            var watcher = DeviceInformation.CreateWatcher(
                BluetoothLEDevice.GetDeviceSelector(),
                null,
                DeviceInformationKind.AssociationEndpoint
            );

            var deviceCount = 0;

            watcher.Added += (sender, deviceInfo) =>
            {
                deviceCount++;
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine($"[{deviceCount}] Found: {deviceInfo.Name ?? "(No Name)"}");
                Console.ResetColor();
                Console.WriteLine($"    ID: {deviceInfo.Id}");
                Console.WriteLine($"    Paired: {deviceInfo.Pairing?.IsPaired ?? false}");
                Console.WriteLine();
            };

            watcher.Updated += (sender, deviceInfoUpdate) =>
            {
                // Device info updated
            };

            watcher.EnumerationCompleted += (sender, args) =>
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("\n[OK] Initial enumeration completed");
                Console.ResetColor();
            };

            watcher.Start();

            // Scan for 15 seconds
            await Task.Delay(15000);

            if (watcher.Status == DeviceWatcherStatus.Started)
            {
                watcher.Stop();
            }

            Console.WriteLine("\n===========================================");
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"Total devices found: {deviceCount}");
            Console.ResetColor();
            Console.WriteLine("===========================================\n");

            if (deviceCount == 0)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("⚠ WARNING: No BLE devices found!");
                Console.WriteLine("\nPossible issues:");
                Console.WriteLine("  1. Bluetooth is disabled in Windows");
                Console.WriteLine("  2. Bluetooth driver issues");
                Console.WriteLine("  3. Simblee is not powered on");
                Console.WriteLine("  4. Simblee firmware not running");
                Console.WriteLine("  5. Need to run as Administrator");
                Console.ResetColor();
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine("💡 TIP: Look for 'RFduino', 'Simblee', or '(No Name)' devices above");
                Console.WriteLine("If you see '(No Name)', the Simblee might be advertising without a name.");
                Console.ResetColor();
            }
        }
    }
}
