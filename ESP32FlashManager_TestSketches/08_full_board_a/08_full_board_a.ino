// =============================================================================
// 08_full_board_a — Full Board Restore Test A
// ESP32 Flash Manager test sketches
// =============================================================================
//
// PURPOSE
// -------
// This sketch exists to provide a known firmware state for testing the Full
// Board Restore feature in ESP32 Flash Manager.
//
// WORKFLOW
// --------
// 1. Upload this sketch via Arduino IDE
// 2. Open ESP32 Flash Manager
// 3. Use Restore Backup to flash a merged 16MB .bin of a known good state
// 4. Confirm the board reboots and the LED behaviour changes
//
// To generate the merged .bin for a full board restore test:
//   In Arduino IDE with the target sketch open:
//   Sketch → Export Compiled Binary
//   Look for the file ending in .ino.merged.bin in the sketch build/ folder.
//   This merged file contains bootloader + partition table + firmware at
//   their correct offsets and can be flashed from address 0x0.
//
// This sketch (A) blinks with a distinctive SOS pattern.
// Full Board Test B (09) blinks with a heartbeat pattern.
// Flash A, then restore a merged .bin of B, confirm the pattern changes.
// Then restore a merged .bin of A, confirm it returns.
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
//   SOS pattern: ... --- ... (dot = 150ms, dash = 450ms, gap = 150ms)
//   Pause 1500ms between repetitions.
//   This is Full Board A. Full Board B has a heartbeat pattern.
//
// =============================================================================

#define LED_PIN 13
#define BAUD_RATE 115200
#define DOT 150
#define DASH 450
#define GAP 150
#define PAUSE 1500

void dot() {
  digitalWrite(LED_PIN, HIGH); delay(DOT);
  digitalWrite(LED_PIN, LOW);  delay(GAP);
}

void dash() {
  digitalWrite(LED_PIN, HIGH); delay(DASH);
  digitalWrite(LED_PIN, LOW);  delay(GAP);
}

void sos() {
  dot(); dot(); dot();         // S
  delay(GAP);
  dash(); dash(); dash();      // O
  delay(GAP);
  dot(); dot(); dot();         // S
  delay(PAUSE);
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(BAUD_RATE);
  delay(500);

  Serial.println();
  Serial.println("==============================");
  Serial.println("  Full Board Test A v1.0");
  Serial.println("  ESP32 Flash Manager Test");
  Serial.println("==============================");
  Serial.println();
  Serial.println("  LED pattern: SOS (... --- ...)");
  Serial.println("  Export a merged .bin of this sketch for full board");
  Serial.println("  restore testing in ESP32 Flash Manager.");
  Serial.println();
  Serial.println("  Sketch -> Export Compiled Binary in Arduino IDE.");
  Serial.println("  Use the file ending in .ino.merged.bin");
  Serial.println("==============================");
}

void loop() {
  sos();
}
