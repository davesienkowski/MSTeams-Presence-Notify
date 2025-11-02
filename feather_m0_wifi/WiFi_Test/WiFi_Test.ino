/*
  Teams Status Monitor - WiFi Test Version
  Tests WiFi and HTTP server WITHOUT LED Matrix

  This minimal version:
  - Tests WiFi connectivity
  - Runs HTTP server
  - Prints status to Serial Monitor only
  - No LED Matrix required!

  Hardware:
  - Adafruit Feather M0 WiFi (ATWINC1500) ONLY

  Libraries Required:
  - WiFi101 (for ATWINC1500)
*/

#include <SPI.h>
#include <WiFi101.h>

// ==================== CONFIGURATION ====================
// WiFi credentials
const char* ssid = "C&D";
const char* password = "sienkows1";

// HTTP server port
const int serverPort = 80;

// ==================== STATUS DEFINITIONS ====================
enum TeamsStatus {
  TEAMS_AVAILABLE = 0,
  TEAMS_BUSY = 1,
  TEAMS_AWAY = 2,
  TEAMS_BE_RIGHT_BACK = 3,
  TEAMS_DO_NOT_DISTURB = 4,
  TEAMS_FOCUSING = 5,
  TEAMS_PRESENTING = 6,
  TEAMS_IN_A_MEETING = 7,
  TEAMS_IN_A_CALL = 8,
  TEAMS_OFFLINE = 9,
  TEAMS_UNKNOWN = 10
};

const char* statusNames[] = {
  "Available",
  "Busy",
  "Away",
  "Be Right Back",
  "Do Not Disturb",
  "Focusing",
  "Presenting",
  "In a Meeting",
  "In a Call",
  "Offline",
  "Unknown"
};

// ==================== GLOBAL OBJECTS ====================
WiFiServer server(serverPort);
TeamsStatus currentStatus = TEAMS_UNKNOWN;
unsigned long lastUpdateTime = 0;
int requestCount = 0;

// ==================== SETUP ====================
void setup() {
  Serial.begin(115200);
  delay(2000);  // Wait for serial monitor

  Serial.println(F("\n=================================================="));
  Serial.println(F("Teams Status Monitor - WiFi Test (No LED Matrix)"));
  Serial.println(F("Board: ATSAMD21G18 (Feather M0 WiFi)"));
  Serial.println(F("==================================================\n"));

  // Check for WiFi module
  Serial.print(F("Checking WiFi module..."));
  if (WiFi.status() == WL_NO_SHIELD) {
    Serial.println(F(" FAILED!"));
    Serial.println(F("\nWiFi module not found!"));
    Serial.println(F("\nTroubleshooting:"));
    Serial.println(F("1. Is this a Feather M0 WIFI board?"));
    Serial.println(F("2. Is 'Adafruit Feather M0' selected in Tools > Board?"));
    Serial.println(F("3. Is WiFi101 library installed?"));
    Serial.println(F("4. Try File > Examples > WiFi101 > CheckWifi101FirmwareVersion"));
    while (1) delay(1000);
  }
  Serial.println(F(" OK"));

  // Print firmware version
  String fv = WiFi.firmwareVersion();
  Serial.print(F("WiFi Firmware version: "));
  Serial.println(fv);

  if (fv < "1.0.0") {
    Serial.println(F("WARNING: Firmware version may be outdated"));
    Serial.println(F("Consider updating via File > Examples > WiFi101 > FirmwareUpdater"));
  }

  // Connect to WiFi
  Serial.print(F("\nConnecting to WiFi: "));
  Serial.println(ssid);
  Serial.print(F("Attempting connection"));

  int attempts = 0;
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println(F("\n\nWiFi connection FAILED!"));
    Serial.println(F("\nTroubleshooting:"));
    Serial.println(F("1. Check WiFi credentials in code"));
    Serial.println(F("2. Verify 2.4GHz network (ATWINC1500 doesn't support 5GHz)"));
    Serial.println(F("3. Move closer to router"));
    Serial.print(F("4. Current WiFi status: "));
    Serial.println(WiFi.status());
    while (1) {
      delay(1000);
    }
  }

  Serial.println(F("\n\n*** Connected! ***"));
  IPAddress ip = WiFi.localIP();
  Serial.print(F("IP Address: "));
  Serial.println(ip);

  long rssi = WiFi.RSSI();
  Serial.print(F("Signal strength: "));
  Serial.print(rssi);
  Serial.println(F(" dBm"));

  // Start HTTP server
  server.begin();
  Serial.println(F("\n*** HTTP server started on port 80 ***"));
  Serial.println(F("\nWork PC should send POST to:"));
  Serial.print(F("  http://"));
  Serial.print(ip);
  Serial.println(F("/status"));
  Serial.println(F("\nJSON format:"));
  Serial.println(F("  {\"status\": 0}  // 0-10"));

  Serial.println(F("\nTest in browser:"));
  Serial.print(F("  http://"));
  Serial.println(ip);

  Serial.println(F("\n=================================================="));
  Serial.println(F("Ready! Waiting for requests..."));
  Serial.println(F("Status updates will appear below in Serial Monitor"));
  Serial.println(F("==================================================\n"));

  // Set initial status
  currentStatus = TEAMS_UNKNOWN;
}

// ==================== MAIN LOOP ====================
void loop() {
  WiFiClient client = server.available();

  if (client) {
    handleClient(client);
  }
}

// ==================== HTTP REQUEST HANDLER ====================
void handleClient(WiFiClient& client) {
  Serial.println(F("=== New client connected ==="));

  String currentLine = "";
  String requestBody = "";
  String requestPath = "";
  bool isPost = false;
  int contentLength = 0;
  bool headersComplete = false;

  while (client.connected()) {
    if (client.available()) {
      char c = client.read();

      if (!headersComplete) {
        currentLine += c;

        if (c == '\n') {
          // Check if line is empty (end of headers)
          if (currentLine.length() == 2 && currentLine[0] == '\r') {
            headersComplete = true;

            // If POST request with body, read it
            if (isPost && contentLength > 0) {
              for (int i = 0; i < contentLength; i++) {
                if (client.available()) {
                  requestBody += (char)client.read();
                }
              }
            }

            // Process request
            if (requestPath.startsWith("/status") && isPost) {
              handleStatusRequest(client, requestBody);
            }
            else if (requestPath.startsWith("/health")) {
              handleHealthRequest(client);
            }
            else if (requestPath == "/" || requestPath.startsWith("/ ")) {
              handleRootRequest(client);
            }
            else {
              send404(client);
            }

            break;
          }
          else {
            // Parse header line
            if (currentLine.startsWith("POST")) {
              isPost = true;
              int spaceIndex = currentLine.indexOf(' ');
              int secondSpace = currentLine.indexOf(' ', spaceIndex + 1);
              requestPath = currentLine.substring(spaceIndex + 1, secondSpace);
            }
            else if (currentLine.startsWith("GET")) {
              int spaceIndex = currentLine.indexOf(' ');
              int secondSpace = currentLine.indexOf(' ', spaceIndex + 1);
              requestPath = currentLine.substring(spaceIndex + 1, secondSpace);
            }
            else if (currentLine.startsWith("Content-Length:")) {
              contentLength = currentLine.substring(16).toInt();
            }

            currentLine = "";
          }
        }
      }
    }
  }

  // Close connection
  delay(10);
  client.stop();
  Serial.println(F("=== Client disconnected ===\n"));
}

// ==================== REQUEST HANDLERS ====================
void handleStatusRequest(WiFiClient& client, String& body) {
  Serial.println(F(">>> POST /status"));
  Serial.print(F("Body: "));
  Serial.println(body);

  // Simple JSON parsing (looking for "status":X)
  int statusValue = -1;
  int statusIndex = body.indexOf("\"status\"");

  if (statusIndex >= 0) {
    int colonIndex = body.indexOf(':', statusIndex);
    if (colonIndex >= 0) {
      String numberStr = "";
      for (int i = colonIndex + 1; i < body.length(); i++) {
        char c = body[i];
        if (c >= '0' && c <= '9') {
          numberStr += c;
        }
        else if (numberStr.length() > 0) {
          break;
        }
      }

      if (numberStr.length() > 0) {
        statusValue = numberStr.toInt();
      }
    }
  }

  if (statusValue >= 0 && statusValue <= 10) {
    currentStatus = (TeamsStatus)statusValue;
    lastUpdateTime = millis();
    requestCount++;

    Serial.println(F("\n*** STATUS UPDATE ***"));
    Serial.print(F("Status: "));
    Serial.print(statusNames[statusValue]);
    Serial.print(F(" ("));
    Serial.print(statusValue);
    Serial.println(F(")"));
    Serial.print(F("Request #"));
    Serial.println(requestCount);
    Serial.println(F("*********************\n"));

    // Send success response
    client.println(F("HTTP/1.1 200 OK"));
    client.println(F("Content-Type: application/json"));
    client.println(F("Connection: close"));
    client.println();
    client.println(F("{\"success\":true}"));
  }
  else {
    Serial.println(F("ERROR: Invalid status value"));

    // Send error response
    client.println(F("HTTP/1.1 400 Bad Request"));
    client.println(F("Content-Type: application/json"));
    client.println(F("Connection: close"));
    client.println();
    client.println(F("{\"error\":\"Invalid status range (0-10)\"}"));
  }
}

void handleHealthRequest(WiFiClient& client) {
  Serial.println(F(">>> GET /health"));

  client.println(F("HTTP/1.1 200 OK"));
  client.println(F("Content-Type: application/json"));
  client.println(F("Connection: close"));
  client.println();
  client.print(F("{\"status\":\"healthy\",\"ip\":\""));
  client.print(WiFi.localIP());
  client.print(F("\",\"board\":\"ATSAMD21G18\",\"output\":\"SERIAL_ONLY\",\"rssi\":"));
  client.print(WiFi.RSSI());
  client.println(F("}"));
}

void handleRootRequest(WiFiClient& client) {
  Serial.println(F(">>> GET /"));

  IPAddress ip = WiFi.localIP();

  client.println(F("HTTP/1.1 200 OK"));
  client.println(F("Content-Type: text/html"));
  client.println(F("Connection: close"));
  client.println();

  client.println(F("<!DOCTYPE html><html><head>"));
  client.println(F("<title>Teams Status - WiFi Test</title>"));
  client.println(F("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"));
  client.println(F("<style>"));
  client.println(F("body{font-family:Arial;margin:20px;background:#1e1e1e;color:#fff}"));
  client.println(F(".container{max-width:600px;margin:0 auto}"));
  client.println(F(".status{padding:20px;background:#2d2d30;border-radius:8px;margin:20px 0}"));
  client.println(F("h1{color:#00bcf2}"));
  client.println(F("code{background:#333;padding:2px 6px;border-radius:3px}"));
  client.println(F(".success{color:#00ff00}"));
  client.println(F("</style></head><body><div class=\"container\">"));
  client.println(F("<h1>✅ Teams Status - WiFi Test</h1>"));
  client.println(F("<div class=\"status\"><h2>WiFi Test Successful!</h2>"));
  client.println(F("<p class=\"success\">HTTP server is working correctly on your ATSAMD21G18!</p>"));
  client.println(F("<p><strong>Board:</strong> Feather M0 WiFi (ATSAMD21G18)</p>"));
  client.println(F("<p><strong>IP Address:</strong> "));
  client.print(ip);
  client.println(F("</p>"));
  client.println(F("<p><strong>Port:</strong> 80</p>"));
  client.println(F("<p><strong>Output:</strong> Serial Monitor Only (LED Matrix not yet connected)</p>"));
  client.print(F("<p><strong>Current Status:</strong> "));
  client.print(statusNames[currentStatus]);
  client.println(F("</p>"));
  client.print(F("<p><strong>Requests Received:</strong> "));
  client.print(requestCount);
  client.println(F("</p></div>"));
  client.println(F("<div class=\"status\"><h2>API Endpoint</h2>"));
  client.println(F("<p><strong>POST</strong> <code>/status</code></p>"));
  client.println(F("<p>Body: <code>{\"status\": 0}</code></p>"));
  client.println(F("<p>Status codes: 0=Available, 1=Busy, 2=Away, 3=BeRightBack, 4=DND, 5=Focusing, 6=Presenting, 7=InMeeting, 8=InCall, 9=Offline, 10=Unknown</p></div>"));
  client.println(F("<div class=\"status\"><h2>Next Steps</h2>"));
  client.println(F("<ol>"));
  client.println(F("<li>✅ WiFi is working!</li>"));
  client.println(F("<li>✅ HTTP server is working!</li>"));
  client.println(F("<li>Configure PowerShell client with this IP address</li>"));
  client.println(F("<li>Solder headers on LED Matrix FeatherWing</li>"));
  client.println(F("<li>Stack LED Matrix on Feather M0 WiFi</li>"));
  client.println(F("<li>Upload full version with LED Matrix support</li>"));
  client.println(F("</ol></div></div></body></html>"));
}

void send404(WiFiClient& client) {
  Serial.println(F(">>> 404 Not Found"));

  client.println(F("HTTP/1.1 404 Not Found"));
  client.println(F("Content-Type: text/plain"));
  client.println(F("Connection: close"));
  client.println();
  client.println(F("404 Not Found"));
}
