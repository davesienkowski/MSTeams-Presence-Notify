/*
 * Teams Status ESP32 WiFi Firmware
 * Receives Teams status via HTTP and displays color on RGB LED
 *
 * Hardware:
 *   - ESP32 DevKit (any variant with WiFi)
 *   - Common Cathode RGB LED + 220Ω resistors on each channel
 *   OR your existing RGB Shield (if compatible with ESP32 pinout)
 *
 * WiFi Advantages over BLE:
 *   - 30-50m range vs 10m BLE
 *   - Rock-solid TCP/IP stack
 *   - No Windows BLE stack issues
 *   - mDNS discovery (teams-status.local)
 *   - Simple HTTP POST protocol
 *
 * Network Protocol:
 *   POST /status HTTP/1.1
 *   Content-Type: application/json
 *   {"status": 0}
 *
 * Status codes match original RFduino implementation (0-10)
 */

#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>

// ==================== CONFIGURATION ====================
// WiFi credentials - CHANGE THESE!
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// mDNS hostname (access via http://teams-status.local)
const char* MDNS_HOSTNAME = "teams-status";

// Web server port
const int HTTP_PORT = 80;

// LED pins (PWM capable) - adjust for your ESP32 board
const int RED_PIN = 25;    // GPIO 25
const int GREEN_PIN = 26;  // GPIO 26
const int BLUE_PIN = 27;   // GPIO 27

// ==================== STATUS CODES ====================
enum Status {
    AVAILABLE = 0,      // Green
    BUSY = 1,           // Red
    AWAY = 2,           // Yellow
    BE_RIGHT_BACK = 3,  // Yellow
    DO_NOT_DISTURB = 4, // Purple
    FOCUSING = 5,       // Purple
    PRESENTING = 6,     // Red
    IN_A_MEETING = 7,   // Red
    IN_A_CALL = 8,      // Red
    OFFLINE = 9,        // Gray/Dim
    UNKNOWN = 10        // White
};

// ==================== GLOBAL STATE ====================
WebServer server(HTTP_PORT);
uint8_t currentStatus = UNKNOWN;
unsigned long lastUpdate = 0;

// ==================== LED CONTROL ====================
void setColor(int red, int green, int blue) {
    // ESP32 uses 8-bit PWM (0-255)
    analogWrite(RED_PIN, red);
    analogWrite(GREEN_PIN, green);
    analogWrite(BLUE_PIN, blue);
}

void updateLED(uint8_t status) {
    switch(status) {
        case AVAILABLE:
            setColor(0, 255, 0);  // Green
            break;

        case BUSY:
        case PRESENTING:
        case IN_A_MEETING:
        case IN_A_CALL:
            setColor(255, 0, 0);  // Red
            break;

        case AWAY:
        case BE_RIGHT_BACK:
            setColor(255, 255, 0);  // Yellow
            break;

        case DO_NOT_DISTURB:
        case FOCUSING:
            setColor(128, 0, 128);  // Purple
            break;

        case OFFLINE:
            setColor(50, 50, 50);  // Dim gray
            break;

        case UNKNOWN:
        default:
            setColor(255, 255, 255);  // White
            break;
    }

    currentStatus = status;
    lastUpdate = millis();
}

// ==================== ANIMATIONS ====================
void fadeIn() {
    for(int i = 0; i <= 255; i += 5) {
        setColor(i, i, i);
        delay(10);
    }
}

void blinkReady() {
    for(int i = 0; i < 3; i++) {
        setColor(0, 255, 0);  // Green = ready
        delay(200);
        setColor(0, 0, 0);    // Off
        delay(200);
    }
}

// ==================== HTTP HANDLERS ====================

// POST /status - Update Teams status
void handleStatus() {
    if (server.method() != HTTP_POST) {
        server.send(405, "text/plain", "Method Not Allowed");
        return;
    }

    String body = server.arg("plain");

    // Parse JSON manually (lightweight alternative to ArduinoJson)
    // Expected format: {"status":0}
    int statusPos = body.indexOf("\"status\"");
    if (statusPos == -1) {
        server.send(400, "text/plain", "Bad Request: Missing 'status' field");
        return;
    }

    int colonPos = body.indexOf(':', statusPos);
    if (colonPos == -1) {
        server.send(400, "text/plain", "Bad Request: Invalid JSON");
        return;
    }

    String statusStr = body.substring(colonPos + 1);
    statusStr.trim();
    if (statusStr.endsWith("}")) {
        statusStr = statusStr.substring(0, statusStr.length() - 1);
    }

    int status = statusStr.toInt();

    // Validate status code
    if (status < 0 || status > UNKNOWN) {
        server.send(400, "text/plain", "Bad Request: Invalid status code");
        return;
    }

    // Update LED
    updateLED(status);

    // Send success response
    server.send(200, "application/json", "{\"success\":true}");

    // Log to serial
    Serial.printf("Status updated: %d\n", status);
}

// GET / - Status page
void handleRoot() {
    String html = R"HTML(
<!DOCTYPE html>
<html>
<head>
    <title>Teams Status Monitor</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial; margin: 20px; background: #1e1e1e; color: #fff; }
        .container { max-width: 600px; margin: 0 auto; }
        .status { padding: 20px; background: #2d2d30; border-radius: 8px; margin: 20px 0; }
        .led-preview { width: 100px; height: 100px; border-radius: 50%; margin: 20px auto;
                       box-shadow: 0 0 20px rgba(255,255,255,0.3); }
        h1 { color: #00bcf2; }
        .info { color: #a0a0a0; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚦 Teams Status Monitor</h1>
        <div class="status">
            <h2>Current Status</h2>
            <div class="led-preview" id="led"></div>
            <p id="status-text">Unknown</p>
            <p class="info">Last update: <span id="last-update">Never</span></p>
        </div>
        <div class="status">
            <h3>Connection Info</h3>
            <p><strong>IP Address:</strong> )HTML" + WiFi.localIP().toString() + R"HTML(</p>
            <p><strong>mDNS:</strong> http://teams-status.local</p>
            <p><strong>SSID:</strong> )HTML" + String(WIFI_SSID) + R"HTML(</p>
            <p><strong>Signal:</strong> )HTML" + String(WiFi.RSSI()) + R"HTML( dBm</p>
        </div>
    </div>
    <script>
        const statusNames = {
            0: 'Available', 1: 'Busy', 2: 'Away', 3: 'Be Right Back',
            4: 'Do Not Disturb', 5: 'Focusing', 6: 'Presenting',
            7: 'In a Meeting', 8: 'In a Call', 9: 'Offline', 10: 'Unknown'
        };
        const statusColors = {
            0: 'rgb(0,255,0)', 1: 'rgb(255,0,0)', 2: 'rgb(255,255,0)',
            3: 'rgb(255,255,0)', 4: 'rgb(128,0,128)', 5: 'rgb(128,0,128)',
            6: 'rgb(255,0,0)', 7: 'rgb(255,0,0)', 8: 'rgb(255,0,0)',
            9: 'rgb(50,50,50)', 10: 'rgb(255,255,255)'
        };

        function updateDisplay() {
            fetch('/api/current')
                .then(r => r.json())
                .then(data => {
                    document.getElementById('led').style.backgroundColor = statusColors[data.status];
                    document.getElementById('status-text').textContent = statusNames[data.status];
                    document.getElementById('last-update').textContent = new Date(data.timestamp).toLocaleString();
                });
        }

        setInterval(updateDisplay, 1000);
        updateDisplay();
    </script>
</body>
</html>
)HTML";
    server.send(200, "text/html", html);
}

// GET /api/current - Get current status (JSON)
void handleCurrent() {
    String json = "{\"status\":" + String(currentStatus) +
                  ",\"timestamp\":" + String(lastUpdate) + "}";
    server.send(200, "application/json", json);
}

// GET /api/health - Health check endpoint
void handleHealth() {
    String json = "{\"status\":\"healthy\",\"uptime\":" + String(millis() / 1000) +
                  ",\"wifi_rssi\":" + String(WiFi.RSSI()) + "}";
    server.send(200, "application/json", json);
}

// ==================== SETUP ====================
void setup() {
    Serial.begin(115200);
    delay(100);

    Serial.println("\n\n========================================");
    Serial.println("Teams Status ESP32 WiFi Monitor");
    Serial.println("========================================\n");

    // Initialize LED pins
    pinMode(RED_PIN, OUTPUT);
    pinMode(GREEN_PIN, OUTPUT);
    pinMode(BLUE_PIN, OUTPUT);

    // Start with fade-in animation
    fadeIn();
    setColor(255, 255, 255);  // White = starting up

    // Connect to WiFi
    Serial.printf("Connecting to WiFi: %s\n", WIFI_SSID);
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
        delay(500);
        Serial.print(".");
        attempts++;

        // Pulse white while connecting
        if (attempts % 2 == 0) {
            setColor(255, 255, 255);
        } else {
            setColor(128, 128, 128);
        }
    }

    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("\n[ERROR] WiFi connection failed!");
        Serial.println("Check your SSID and password in the code.");
        // Blink red to indicate error
        while(true) {
            setColor(255, 0, 0);
            delay(500);
            setColor(0, 0, 0);
            delay(500);
        }
    }

    Serial.println("\n[OK] WiFi connected!");
    Serial.printf("IP Address: %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("Signal Strength: %d dBm\n", WiFi.RSSI());

    // Start mDNS responder
    if (MDNS.begin(MDNS_HOSTNAME)) {
        Serial.printf("mDNS responder started: http://%s.local\n", MDNS_HOSTNAME);
        MDNS.addService("http", "tcp", HTTP_PORT);
    } else {
        Serial.println("[WARN] mDNS responder failed to start");
    }

    // Configure HTTP routes
    server.on("/", HTTP_GET, handleRoot);
    server.on("/status", HTTP_POST, handleStatus);
    server.on("/api/current", HTTP_GET, handleCurrent);
    server.on("/api/health", HTTP_GET, handleHealth);

    // 404 handler
    server.onNotFound([]() {
        server.send(404, "text/plain", "Not Found");
    });

    // Start web server
    server.begin();
    Serial.printf("\n[OK] HTTP server started on port %d\n", HTTP_PORT);
    Serial.println("\nReady to receive Teams status updates!");
    Serial.println("========================================\n");

    // Blink green to show ready
    blinkReady();
    updateLED(UNKNOWN);
}

// ==================== MAIN LOOP ====================
void loop() {
    // Handle HTTP requests
    server.handleClient();

    // Keep mDNS alive
    MDNS.update();

    // Check WiFi connection
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[WARN] WiFi disconnected! Attempting reconnect...");
        WiFi.reconnect();
        delay(5000);
    }

    delay(10);  // Small delay to prevent watchdog issues
}
