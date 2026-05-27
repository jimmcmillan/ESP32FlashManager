// =============================================================================
// 01_blink_a — Firmware Test A
// ESP32 Flash Manager test sketches
// =============================================================================
//
// PURPOSE
// -------
// A simple, identifiable firmware for testing the Flash Region and Read/Backup
// operations in ESP32 Flash Manager. Blinks the onboard LED slowly (1 Hz) and
// prints a clear identity message to Serial on boot.
//
// Use this sketch to:
//   - Test flashing a .bin to the app0 region (0x10000)
//   - Read/backup the app0 region and confirm file size
//   - Visually confirm a successful flash by the slow blink pattern
//   - Distinguish from Firmware Test B (which blinks fast)
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
//   Slow blink — 500ms on, 500ms off (1 Hz)
//   This is Firmware A. Firmware B blinks fast.
//
// =============================================================================

#define LED_PIN 13
#define BAUD_RATE 115200
#define SKETCH_NAME "Firmware Test A"
#define SKETCH_VERSION "1.0"
#define BLINK_ON_MS 500
#define BLINK_OFF_MS 500

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
  Serial.println("  LED pattern: SLOW blink (1 Hz)");
  Serial.println("  Flash region: app0 at 0x10000");
  Serial.println("  Use Read/Backup to save this firmware.");
  Serial.println("  Flash Firmware Test B to replace it.");
  Serial.println();
  Serial.println("  Running...");
}

void loop() {
  digitalWrite(LED_PIN, HIGH);
  delay(BLINK_ON_MS);
  digitalWrite(LED_PIN, LOW);
  delay(BLINK_OFF_MS);
}
