using System;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

namespace TeamsBLETransmitter
{
    public class TeamsLogMonitor
    {
        private readonly string _logPath;
        private readonly bool _verbose;
        private TeamsStatus _lastStatus = TeamsStatus.Unknown;

        // Regex patterns for both Classic and New Teams
        // Classic Teams: "Setting the taskbar overlay icon - Away"
        // New Teams: "SetBadge Setting badge:.*status Away" or "availability: Away"
        private static readonly Regex StatusChangePattern = new(@"(?:SetBadge Setting badge:.*status |Setting the taskbar overlay icon - |availability: )(\w+)", RegexOptions.Compiled | RegexOptions.IgnoreCase);
        private static readonly Regex CallActivityPattern = new(@"(?:name: desktop_call_state_change_send|StatusIndicatorStateService: Added )(\w+)", RegexOptions.Compiled | RegexOptions.IgnoreCase);

        public TeamsLogMonitor(string logPath, bool verbose = false)
        {
            _logPath = logPath;
            _verbose = verbose;
        }

        public TeamsStatus GetCurrentStatus()
        {
            try
            {
                string? latestLogFile = null;

                if (_verbose)
                {
                    Console.WriteLine($"[DEBUG] Checking log path: {_logPath}");
                }

                // Check if path is a directory (New Teams) or file (Classic Teams)
                if (Directory.Exists(_logPath))
                {
                    // New Teams - find most recent log file
                    var logFiles = Directory.GetFiles(_logPath, "*.log", SearchOption.TopDirectoryOnly);

                    if (_verbose)
                    {
                        Console.WriteLine($"[DEBUG] Found {logFiles.Length} log files");
                    }

                    if (logFiles.Length == 0)
                    {
                        if (_verbose)
                        {
                            Console.WriteLine("[DEBUG] No log files found - status: Offline");
                        }
                        return TeamsStatus.Offline;
                    }

                    latestLogFile = logFiles
                        .OrderByDescending(f => File.GetLastWriteTime(f))
                        .FirstOrDefault();

                    if (_verbose && latestLogFile != null)
                    {
                        Console.WriteLine($"[DEBUG] Using latest log: {Path.GetFileName(latestLogFile)}");
                        Console.WriteLine($"[DEBUG] Last modified: {File.GetLastWriteTime(latestLogFile)}");
                    }
                }
                else if (File.Exists(_logPath))
                {
                    // Classic Teams
                    latestLogFile = _logPath;
                    if (_verbose)
                    {
                        Console.WriteLine($"[DEBUG] Using Classic Teams log: {latestLogFile}");
                    }
                }

                if (latestLogFile == null)
                {
                    if (_verbose)
                    {
                        Console.WriteLine("[DEBUG] No log file found - status: Offline");
                    }
                    return TeamsStatus.Offline;
                }

                // Read last 5000 characters (similar to Python implementation)
                var fileInfo = new FileInfo(latestLogFile);
                var readSize = Math.Min(5000, (int)fileInfo.Length);

                if (_verbose)
                {
                    Console.WriteLine($"[DEBUG] File size: {fileInfo.Length} bytes, reading last {readSize} bytes");
                }

                using var stream = new FileStream(latestLogFile, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                if (readSize < fileInfo.Length)
                {
                    stream.Seek(-readSize, SeekOrigin.End);
                }

                using var reader = new StreamReader(stream);
                var logContent = reader.ReadToEnd();

                if (_verbose)
                {
                    Console.WriteLine($"[DEBUG] Read {logContent.Length} characters from log");

                    // Show last few lines for debugging
                    var lines = logContent.Split('\n').Where(l => !string.IsNullOrWhiteSpace(l)).TakeLast(5);
                    Console.WriteLine("[DEBUG] Last 5 non-empty lines:");
                    foreach (var line in lines)
                    {
                        Console.WriteLine($"  {line.Trim()}");
                    }
                }

                // Parse status from log content
                var status = ParseStatus(logContent);

                if (_verbose)
                {
                    Console.WriteLine($"[DEBUG] Parsed status: {status} (code: {(int)status})");
                    Console.WriteLine($"[DEBUG] Last sent status: {_lastStatus} (code: {(int)_lastStatus})");
                }

                // Only update if status changed
                if (status != _lastStatus && status != TeamsStatus.Unknown)
                {
                    _lastStatus = status;
                    if (_verbose)
                    {
                        Console.WriteLine($"[DEBUG] Status updated: {_lastStatus}");
                    }
                }

                return _lastStatus;
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine($"[!] Error reading Teams log: {ex.Message}");
                Console.ResetColor();
                return TeamsStatus.Unknown;
            }
        }

        private TeamsStatus ParseStatus(string logContent)
        {
            TeamsStatus? callStatus = null;
            TeamsStatus? presenceStatus = null;

            // Find all status change matches
            var statusMatches = StatusChangePattern.Matches(logContent);

            if (_verbose)
            {
                Console.WriteLine($"[DEBUG] Found {statusMatches.Count} status change patterns");
            }

            if (statusMatches.Count > 0)
            {
                var lastMatch = statusMatches[statusMatches.Count - 1];
                var statusString = lastMatch.Groups[1].Value;
                presenceStatus = ParseStatusString(statusString);

                if (_verbose)
                {
                    Console.WriteLine($"[DEBUG] Last status pattern: '{statusString}' -> {presenceStatus}");
                }
            }

            // Find all call activity matches
            var callMatches = CallActivityPattern.Matches(logContent);

            if (_verbose)
            {
                Console.WriteLine($"[DEBUG] Found {callMatches.Count} call activity patterns");
            }

            if (callMatches.Count > 0)
            {
                var lastMatch = callMatches[callMatches.Count - 1];
                var callString = lastMatch.Groups[1].Value;
                callStatus = ParseStatusString(callString);

                if (_verbose)
                {
                    Console.WriteLine($"[DEBUG] Last call pattern: '{callString}' -> {callStatus}");
                }
            }

            // Call status takes precedence over presence status
            var finalStatus = callStatus ?? presenceStatus ?? TeamsStatus.Unknown;

            if (_verbose)
            {
                Console.WriteLine($"[DEBUG] Final status: {finalStatus} (call: {callStatus}, presence: {presenceStatus})");
            }

            return finalStatus;
        }

        private TeamsStatus ParseStatusString(string status)
        {
            return status.ToLower() switch
            {
                "available" => TeamsStatus.Available,
                "busy" => TeamsStatus.Busy,
                "donotdisturb" or "dnd" => TeamsStatus.DoNotDisturb,
                "away" => TeamsStatus.Away,
                "berightback" or "brb" => TeamsStatus.BeRightBack,
                "focusing" => TeamsStatus.Focusing,
                "inameeting" or "meeting" => TeamsStatus.InAMeeting,
                "inacall" or "call" => TeamsStatus.InACall,
                "presenting" => TeamsStatus.Presenting,
                "offline" => TeamsStatus.Offline,
                _ => TeamsStatus.Unknown
            };
        }
    }
}
