#include <WiFi101.h>


void setup() {
  Serial.begin(115200);
  delay(2000);
  
  Serial.println("Testing WiFi module...");
  
  // Check for WiFi module
  if (WiFi.status() == WL_NO_SHIELD) {
    Serial.println("ERROR: WiFi module not found!");
    Serial.println("Check:");
    Serial.println("1. Is this a Feather M0 WiFi board?");
    Serial.println("2. Is the board selected correctly?");
    Serial.println("3. Is WiFi101 library installed?");
    while (1);
  }
  
  Serial.println("WiFi module found!");
  
  String fv = WiFi.firmwareVersion();
  Serial.print("Firmware version: ");
  Serial.println(fv);
  
  Serial.println("WiFi test PASSED!");
}

void loop() {
}