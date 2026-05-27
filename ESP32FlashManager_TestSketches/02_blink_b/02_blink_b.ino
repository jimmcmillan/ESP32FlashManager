// =============================================================================
// 02_blink_b — Firmware Test B
// ESP32 Flash Manager test sketches
// =============================================================================
//
// PURPOSE
// -------
// A second identifiable firmware for testing flash and restore operations.
// Blinks the onboard LED fast (5 Hz) so it is immediately visually distinct
// from Firmware Test A (slow blink).
//
// Use this sketch to:
//   - Flash over Firmware A and confirm the region was written (LED changes)
//   - Restore the Firmware A backup and confirm the LED returns to slow blink
//   - Test the full flash/backup/restore cycle on the app0 region
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
//   Fast blink — 100ms on, 100ms off (5 Hz)
//   This is Firmware B. Firmware A blinks slow.
//
// =============================================================================

#define LED_PIN 13
#define BAUD_RATE 115200
#define SKETCH_NAME "Firmware Test B"
#define SKETCH_VERSION "1.0"
#define BLINK_ON_MS 100
#define BLINK_OFF_MS 100

void setup() {
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(BAUD_RATE);
  delay(500);

  Serial.println();
  Serial.println("==============================");
  Serial.println("  " + String(SKETCH_NAME) + " v" + String(SKETCH_VERSION));
  Serial.println("  ESP32 Flash Manager Test");
  Serial.println("==============================");
  Serial.println();
  Serial.println("  LED pattern: FAST blink (5 Hz)");
  Serial.println("  Flash region: app0 at 0x10000");
  Serial.println("  Restore Firmware A backup to return to slow blink.");
  Serial.println();
  Serial.println("  Running...");
}

void loop() {
  digitalWrite(LED_PIN, HIGH);
  delay(BLINK_ON_MS);
  digitalWrite(LED_PIN, LOW);
  delay(BLINK_OFF_MS);
}
