// =============================================================================
// 04_spiffs_write — SPIFFS Write Test
// ESP32 Flash Manager test sketches
// =============================================================================
//
// PURPOSE
// -------
// Formats the SPIFFS partition, writes three test files to it, then reads them
// back and verifies the contents. Used to put known data into SPIFFS so it can
// be backed up, erased, and restored using ESP32 Flash Manager.
//
// Use this sketch to:
//   - Put known, verifiable data into the SPIFFS region (0x210000)
//   - Then use the app to Read/Backup the SPIFFS region
//   - Erase SPIFFS using the app and flash 05_spiffs_verify to confirm erasure
//   - Restore the SPIFFS backup using the app and flash 05_spiffs_verify to
//     confirm the files came back
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
//   3 rapid flashes on boot — sketch started
//   Solid on during write operations
//   Slow blink after complete — all tests passed
//   Fast blink after complete — one or more tests failed
//
// =============================================================================

#include "SPIFFS.h"

#define LED_PIN 13
#define BAUD_RATE 115200

bool allPassed = true;

void flashLED(int count, int onMs, int offMs) {
  for (int i = 0; i < count; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(onMs);
    digitalWrite(LED_PIN, LOW);
    delay(offMs);
  }
}

bool writeAndVerify(const char* path, const char* content) {
  File f = SPIFFS.open(path, FILE_WRITE);
  if (!f) {
    Serial.printf("  FAIL: Could not open %s for write\n", path);
    return false;
  }
  f.print(content);
  f.close();

  f = SPIFFS.open(path, FILE_READ);
  if (!f) {
    Serial.printf("  FAIL: Could not open %s for read\n", path);
    return false;
  }
  String readBack = f.readString();
  f.close();

  if (readBack == String(content)) {
    Serial.printf("  PASS: %s\n", path);
    return true;
  } else {
    Serial.printf("  FAIL: %s — content mismatch\n", path);
    Serial.printf("    Expected: %s\n", content);
    Serial.printf("    Got:      %s\n", readBack.c_str());
    return false;
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(BAUD_RATE);
  delay(500);
  flashLED(3, 80, 80);

  Serial.println();
  Serial.println("==============================");
  Serial.println("  SPIFFS Write Test v1.0");
  Serial.println("  ESP32 Flash Manager Test");
  Serial.println("==============================");
  Serial.println();

  // Format SPIFFS
  Serial.println("  Formatting SPIFFS...");
  digitalWrite(LED_PIN, HIGH);
  if (!SPIFFS.format()) {
    Serial.println("  FAIL: SPIFFS format failed.");
    allPassed = false;
  } else {
    Serial.println("  OK: SPIFFS formatted.");
  }

  // Mount
  if (!SPIFFS.begin(false)) {
    Serial.println("  FAIL: SPIFFS mount failed.");
    allPassed = false;
  } else {
    Serial.println("  OK: SPIFFS mounted.");
  }

  Serial.println();
  Serial.println("--- Writing test files ---");

  allPassed &= writeAndVerify(
    "/test_a.txt",
    "ESP32 Flash Manager SPIFFS test file A. "
    "This file was written by 04_spiffs_write. "
    "If you can read this after a restore, the restore worked."
  );

  allPassed &= writeAndVerify(
    "/test_b.txt",
    "ESP32 Flash Manager SPIFFS test file B. "
    "Second file for multi-file verification."
  );

  allPassed &= writeAndVerify(
    "/info.txt",
    "SPIFFS region: 0x210000\n"
    "Written by: 04_spiffs_write v1.0\n"
    "Purpose: ESP32 Flash Manager backup/restore testing\n"
  );

  Serial.println();
  Serial.println("--- SPIFFS Summary ---");
  Serial.printf("  Total:     %d bytes\n", SPIFFS.totalBytes());
  Serial.printf("  Used:      %d bytes\n", SPIFFS.usedBytes());
  Serial.printf("  Free:      %d bytes\n", SPIFFS.totalBytes() - SPIFFS.usedBytes());
  Serial.println();

  if (allPassed) {
    Serial.println("  ALL TESTS PASSED.");
    Serial.println("  You can now use ESP32 Flash Manager to:");
    Serial.println("  1. Read/Backup the SPIFFS region (0x210000)");
    Serial.println("  2. Erase the SPIFFS region");
    Serial.println("  3. Flash 05_spiffs_verify to confirm erasure");
    Serial.println("  4. Restore the SPIFFS backup");
    Serial.println("  5. Flash 05_spiffs_verify to confirm restore");
  } else {
    Serial.println("  ONE OR MORE TESTS FAILED.");
  }

  Serial.println("==============================");
  digitalWrite(LED_PIN, LOW);
}

void loop() {
  if (allPassed) {
    // Slow blink = all good
    digitalWrite(LED_PIN, HIGH); delay(800);
    digitalWrite(LED_PIN, LOW);  delay(800);
  } else {
    // Fast blink = something failed
    digitalWrite(LED_PIN, HIGH); delay(100);
    digitalWrite(LED_PIN, LOW);  delay(100);
  }
}
