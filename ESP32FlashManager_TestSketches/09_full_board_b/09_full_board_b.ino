// =============================================================================
// 09_full_board_b — Full Board Restore Test B
// ESP32 Flash Manager test sketches
// =============================================================================
//
// PURPOSE
// -------
// Companion to 08_full_board_a. Provides a second visually distinct firmware
// state for testing the Full Board Restore feature. Use this sketch alongside
// Full Board Test A to confirm complete board backup and restore cycles.
//
// WORKFLOW
// --------
// 1. Upload Full Board A via Arduino IDE — note the SOS blink pattern
// 2. Export a merged .bin of Full Board A (Sketch → Export Compiled Binary)
// 3. Upload Full Board B via Arduino IDE — note the heartbeat pattern
// 4. Export a merged .bin of Full Board B
// 5. In ESP32 Flash Manager, use Restore Backup with the Full Board A .bin
// 6. Confirm the board reboots and returns to the SOS pattern
// 7. Restore Full Board B .bin and confirm the heartbeat returns
//
// ARDUINO IDE SETTINGS
// --------------------
//   Board:            ESP32 Dev Module
//   Flash Size:       16MB (128Mb)
//   Partition Scheme: Custom
//   Upload Speed:     921600
//   Serial Monitor:   115200 baud
//
// LED BEHAVIOUR
// -------------
//   Heartbeat: two quick pulses, long pause. Repeating.
//   This is Full Board B. Full Board A has an SOS pattern.
//
// =============================================================================

#define LED_PIN 13
#define BAUD_RATE 115200

void heartbeat() {
  // First beat
  digitalWrite(LED_PIN, HIGH); delay(80);
  digitalWrite(LED_PIN, LOW);  delay(120);
  // Second beat
  digitalWrite(LED_PIN, HIGH); delay(80);
  digitalWrite(LED_PIN, LOW);  delay(800);
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(BAUD_RATE);
  delay(500);

  Serial.println();
  Serial.println("==============================");
  Serial.println("  Full Board Test B v1.0");
  Serial.println("  ESP32 Flash Manager Test");
  Serial.println("==============================");
  Serial.println();
  Serial.println("  LED pattern: Heartbeat (two pulses, long pause)");
  Serial.println("  Export a merged .bin of this sketch for full board");
  Serial.println("  restore testing in ESP32 Flash Manager.");
  Serial.println();
  Serial.println("  Sketch -> Export Compiled Binary in Arduino IDE.");
  Serial.println("  Use the file ending in .ino.merged.bin");
  Serial.println("==============================");
}

void loop() {
  heartbeat();
}
