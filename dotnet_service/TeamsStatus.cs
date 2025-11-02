namespace TeamsBLETransmitter
{
    /// <summary>
    /// Teams presence status codes matching RFduino firmware
    /// </summary>
    public enum TeamsStatus
    {
        Available = 0,      // Green
        Busy = 1,           // Red
        Away = 2,           // Yellow
        BeRightBack = 3,    // Yellow
        DoNotDisturb = 4,   // Purple
        Focusing = 5,       // Purple
        Presenting = 6,     // Red
        InAMeeting = 7,     // Red
        InACall = 8,        // Red
        Offline = 9,        // Dim gray
        Unknown = 10        // White
    }

    public static class TeamsStatusExtensions
    {
        public static string ToDisplayString(this TeamsStatus status)
        {
            return status switch
            {
                TeamsStatus.Available => "Available",
                TeamsStatus.Busy => "Busy",
                TeamsStatus.DoNotDisturb => "Do Not Disturb",
                TeamsStatus.Away => "Away",
                TeamsStatus.BeRightBack => "Be Right Back",
                TeamsStatus.Focusing => "Focusing",
                TeamsStatus.InAMeeting => "In a Meeting",
                TeamsStatus.Presenting => "Presenting",
                TeamsStatus.Offline => "Offline",
                _ => "Unknown"
            };
        }

        public static ConsoleColor ToConsoleColor(this TeamsStatus status)
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
}
