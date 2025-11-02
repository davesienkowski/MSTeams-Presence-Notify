using System;
using System.IO;

namespace TeamsBLETransmitter
{
    public class Configuration
    {
        public string TeamsLogPath { get; set; }
        public int CheckIntervalSeconds { get; set; } = 5;
        public string? RFduinoDeviceName { get; set; } = "RFduino";
        public bool VerboseLogging { get; set; } = false;

        // RFduino uses custom UUIDs (these are placeholders - actual discovery happens at runtime)
        // Service: 2d30c082-f39f-4ce6-923f-3484ea480596
        // TX Char: 2d30c083-f39f-4ce6-923f-3484ea480596
        public Guid RFduinoServiceUuid { get; set; } = Guid.Parse("2d30c082-f39f-4ce6-923f-3484ea480596");
        public Guid RFduinoCharacteristicUuid { get; set; } = Guid.Parse("2d30c083-f39f-4ce6-923f-3484ea480596");

        public Configuration(string[] args)
        {
            // Default Teams log path
            TeamsLogPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                @"Microsoft\Teams\logs.txt"
            );

            // Parse command line arguments
            for (int i = 0; i < args.Length; i++)
            {
                switch (args[i].ToLower())
                {
                    case "--interval":
                    case "-i":
                        if (i + 1 < args.Length && int.TryParse(args[i + 1], out int interval))
                        {
                            CheckIntervalSeconds = interval;
                            i++;
                        }
                        break;

                    case "--log-path":
                    case "-l":
                        if (i + 1 < args.Length)
                        {
                            TeamsLogPath = args[i + 1];
                            i++;
                        }
                        break;

                    case "--device-name":
                    case "-d":
                        if (i + 1 < args.Length)
                        {
                            RFduinoDeviceName = args[i + 1];
                            i++;
                        }
                        break;

                    case "--verbose":
                    case "-v":
                        VerboseLogging = true;
                        break;

                    case "--help":
                    case "-h":
                        ShowHelp();
                        Environment.Exit(0);
                        break;
                }
            }

            // Check if New Teams log directory exists
            var newTeamsLogDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                @"Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Logs"
            );

            if (Directory.Exists(newTeamsLogDir) && !File.Exists(TeamsLogPath))
            {
                // Use New Teams log directory
                TeamsLogPath = newTeamsLogDir;
            }
        }

        private void ShowHelp()
        {
            Console.WriteLine("Teams BLE Transmitter - Usage:");
            Console.WriteLine();
            Console.WriteLine("  TeamsBLETransmitter.exe [options]");
            Console.WriteLine();
            Console.WriteLine("Options:");
            Console.WriteLine("  -i, --interval <seconds>     Check interval (default: 5)");
            Console.WriteLine("  -l, --log-path <path>        Teams log file/directory path");
            Console.WriteLine("  -d, --device-name <name>     RFduino device name (default: RFduino)");
            Console.WriteLine("  -v, --verbose                Enable verbose logging");
            Console.WriteLine("  -h, --help                   Show this help");
            Console.WriteLine();
            Console.WriteLine("Examples:");
            Console.WriteLine("  TeamsBLETransmitter.exe");
            Console.WriteLine("  TeamsBLETransmitter.exe -i 10 -v");
            Console.WriteLine("  TeamsBLETransmitter.exe -d \"RFduino\" -i 5 --verbose");
        }
    }
}
