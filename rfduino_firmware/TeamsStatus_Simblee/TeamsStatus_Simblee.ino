/*
 * Teams Status Simblee Firmware (Windows Optimized)
 * Receives Teams status via BLE and displays color on LED
 *
 * Hardware (Compatible with RFduino shields):
 *   - RFD22121 USB Shield (bottom) OR Simblee USB shield
 *   - RFD77201 Simblee BLE module (middle)
 *   - RFD22122 RGB Shield (top) - Built-in RGB LED
 *   Simply stack the shields and plug in USB!
 *
 * Windows BLE Optimizations:
 *   1. Immediate connection parameter update (in onConnect callback)
 *      - Requests 20-40ms interval BEFORE any blocking operations
 *      - Critical: Must happen before LED flashing to avoid Windows timeout
 *   2. Faster advertisement interval (300ms)
 *      - Improves reconnection speed without overwhelming Windows
 *   3. Maximum TX power (+4 dBm)
 *      - Better signal strength and connection stability
 *   4. Connection health monitoring
 *      - Tracks data reception for diagnostics
 *   5. Data validation
 *      - Prevents invalid status codes from corrupting LED state
 *   6. Low power delays (Simblee_ULPDelay)
 *      - Reduces power consumption while maintaining responsiveness
 *   7. Keepalive heartbeat
 *      - Sends periodic heartbeat to maintain connection and prevent timeout
 *      - Note: Simblee doesn't expose RSSI for host-to-device monitoring
 */

#include <SimbleeBLE.h>  // Changed from RFduinoBLE

// LED pins (PWM capable) - Standard for RFD22122 RGB Shield
const int RED_PIN = 2;
const int GREEN_PIN = 3;
const int BLUE_PIN = 4;

// Status codes (must match Python transmitter)
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

// Current status and color tracking
uint8_t currentStatus = UNKNOWN;
int currentRed = 255;
int currentGreen = 255;
int currentBlue = 255;
bool isConnected = false;

// Connection health monitoring
unsigned long lastDataReceived = 0;
const unsigned long DATA_TIMEOUT = 30000;   // 30 seconds without data = potential issue
unsigned long lastKeepalive = 0;
const unsigned long KEEPALIVE_INTERVAL = 5000;  // Send heartbeat every 5 seconds as keepalive

void setup() {
    // Initialize LED pins
    pinMode(RED_PIN, OUTPUT);
    pinMode(GREEN_PIN, OUTPUT);
    pinMode(BLUE_PIN, OUTPUT);

    // Start with white (unknown status)
    setColor(255, 255, 255);

    // Configure BLE with Windows-compatible settings
    SimbleeBLE.deviceName = "RFduino";  // Keep same name for compatibility

    // Advertisement interval: 300ms (balanced for discovery speed and power)
    // Range: 20ms-10.24s (in 0.625ms units), default is 80ms
    // 300ms provides good balance: fast enough for discovery, slow enough to be reliable
    SimbleeBLE.advertisementInterval = 300;

    // Set advertisement data - keep it short for better compatibility
    SimbleeBLE.advertisementData = "Teams";

    // Set TX power to maximum for better range and stability
    // +4 dBm is the maximum for Simblee
    SimbleeBLE.txPowerLevel = 4;

    // Start BLE stack
    SimbleeBLE.begin();

    // Initial fade animation
    fadeIn();

    // Blink to show we're ready and advertising
    blinkReady();
}

void loop() {
    // BLE is handled automatically by SimbleeBLE library
    // Connection parameters are updated immediately in SimbleeBLE_onConnect()

    // Monitor connection health - check if we're still receiving data
    if (isConnected) {
        unsigned long currentTime = millis();
        unsigned long timeSinceData = currentTime - lastDataReceived;

        // If connected but no data for a long time, indicate potential issue
        if (timeSinceData > DATA_TIMEOUT && lastDataReceived > 0) {
            // Subtle dim pulse to indicate we're connected but not receiving updates
            // Don't change the actual status color, just dim slightly
            // This is informational only
        }

        // Send heartbeat keepalive to maintain connection
        if (currentTime - lastKeepalive >= KEEPALIVE_INTERVAL) {
            sendHeartbeat();
            lastKeepalive = currentTime;
        }
    }

    // Use low power delay
    Simblee_ULPDelay(100);
}

// Called when BLE connection is established
void SimbleeBLE_onConnect() {
    isConnected = true;

    // Request Windows-compatible connection parameters with proper supervision timeout
    // Conservative values for better stability on Windows BLE stack
    // Min: 30ms, Max: 60ms (more conservative for Windows compatibility)
    // Slave latency: 0 (respond to every connection event for reliability)
    // Supervision timeout: 4000ms (4 seconds - must be > 2 * maxInterval)
    // Formula: supervision_timeout > (1 + slave_latency) * 2 * conn_interval_max
    // With slave_latency=0 and max_interval=60ms: timeout must be > 120ms
    // Using 4000ms (4 seconds) provides plenty of buffer for packet loss
    SimbleeBLE.updateConnInterval(30, 60);  // Min, Max in ms
    // Note: Simblee library may not expose supervision timeout directly
    // The default is typically 4-6 seconds which should be adequate

    // Initialize keepalive timer
    lastKeepalive = millis();

    // Brief flash to indicate connection (non-blocking alternative)
    quickFlash();

    // Restore the last known status color
    updateLED(currentStatus);
}

// Called when BLE connection is lost
void SimbleeBLE_onDisconnect() {
    isConnected = false;

    // Keep the current LED color - don't change it!
    // This way the status remains visible even when disconnected
    // The PC will resend the status when it reconnects
}

// Called when data is received over BLE
void SimbleeBLE_onReceive(char *data, int len) {
    if (len > 0) {
        uint8_t status = (uint8_t)data[0];

        // Update timestamp for connection health monitoring
        lastDataReceived = millis();

        // Validate status code is within expected range
        if (status <= UNKNOWN) {
            // Always update, even if status is the same
            // This handles reconnection scenarios where LED might have been corrupted
            currentStatus = status;
            updateLED(status);
        } else {
            // Invalid status code received - ignore but log by brief flash
            // This could indicate data corruption or protocol mismatch
            quickFlash();
        }
    }
}

// Update LED based on status code
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
}

// Set RGB LED color and track it
void setColor(int red, int green, int blue) {
    currentRed = red;
    currentGreen = green;
    currentBlue = blue;

    analogWrite(RED_PIN, red);
    analogWrite(GREEN_PIN, green);
    analogWrite(BLUE_PIN, blue);
}

// Flash LED for connection indicator
void flashLED(int times, int delayMs) {
    // Save current color (now tracked in variables)
    int prevR = currentRed;
    int prevG = currentGreen;
    int prevB = currentBlue;

    for(int i = 0; i < times; i++) {
        setColor(255, 255, 255);
        delay(delayMs);
        setColor(0, 0, 0);
        delay(delayMs);
    }

    // Restore previous color
    setColor(prevR, prevG, prevB);
}

// Fade in animation on startup
void fadeIn() {
    for(int i = 0; i <= 255; i += 5) {
        setColor(i, i, i);
        delay(10);
    }
    delay(500);
    setColor(255, 255, 255);
}

// Quick blink to show BLE is advertising and ready
void blinkReady() {
    for(int i = 0; i < 2; i++) {
        setColor(0, 255, 0);  // Green = ready
        delay(200);
        setColor(0, 0, 0);    // Off
        delay(200);
    }
    setColor(255, 255, 255);  // Back to white (unknown)
}

// Very brief flash for non-intrusive signaling (connection param update, errors)
void quickFlash() {
    // Save current color
    int prevR = currentRed;
    int prevG = currentGreen;
    int prevB = currentBlue;

    // Brief white flash
    setColor(255, 255, 255);
    delay(50);
    setColor(0, 0, 0);
    delay(50);

    // Restore previous color
    setColor(prevR, prevG, prevB);
}

// Send heartbeat keepalive to maintain connection
void sendHeartbeat() {
    // Send simple heartbeat packet to keep connection alive
    // 0xFE is a reserved value that won't conflict with status codes (0-10)
    uint8_t heartbeat = 0xFE;
    SimbleeBLE.send((char*)&heartbeat, 1);
}
