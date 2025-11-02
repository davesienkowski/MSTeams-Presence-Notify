/*
 * Teams Status RFduino Firmware
 * Receives Teams status via BLE and displays color on LED
 *
 * Hardware Option 1 (Recommended - No wiring needed!):
 *   - RFD22121 USB Shield (bottom)
 *   - RFD22102 RFduino BLE module (middle)
 *   - RFD22122 RGB Shield (top) - Built-in RGB LED
 *   Simply stack the shields and plug in USB!
 *
 * Hardware Option 2 (Custom LED):
 *   - RFduino board
 *   - RGB LED (Common Cathode)
 *   - 3x 220Ω resistors
 *   LED Connections:
 *     Pin 2 (Red)   -> 220Ω resistor -> LED Red anode -> Ground
 *     Pin 3 (Green) -> 220Ω resistor -> LED Green anode -> Ground
 *     Pin 4 (Blue)  -> 220Ω resistor -> LED Blue anode -> Ground
 */

#include <RFduinoBLE.h>

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

void setup() {
    // Initialize LED pins
    pinMode(RED_PIN, OUTPUT);
    pinMode(GREEN_PIN, OUTPUT);
    pinMode(BLUE_PIN, OUTPUT);

    // Start with white (unknown status)
    setColor(255, 255, 255);

    // Configure BLE
    RFduinoBLE.deviceName = "RFduino";
    RFduinoBLE.advertisementData = "Teams";
    RFduinoBLE.advertisementInterval = 300; // ms

    // Start BLE stack
    RFduinoBLE.begin();

    // Initial fade animation
    fadeIn();
}

void loop() {
    // BLE is handled automatically by RFduinoBLE library
    // Just keep the LED updated
    delay(100);
}

// Called when BLE connection is established
void RFduinoBLE_onConnect() {
    // Flash LED to indicate connection, then restore current status
    flashLED(3, 100);
    // Restore the last known status color
    updateLED(currentStatus);
}

// Called when BLE connection is lost
void RFduinoBLE_onDisconnect() {
    // Keep the current LED color - don't change it!
    // This way the status remains visible even when disconnected
    // The PC will resend the status when it reconnects
}

// Called when data is received over BLE
void RFduinoBLE_onReceive(char *data, int len) {
    if (len > 0) {
        uint8_t status = (uint8_t)data[0];

        // Always update, even if status is the same
        // This handles reconnection scenarios where LED might have been corrupted
        currentStatus = status;
        updateLED(status);
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
