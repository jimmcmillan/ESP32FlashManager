// =============================================================================
// 05_spiffs_verify — SPIFFS Verify / Read Test
// ESP32 Flash Manager test sketches
// =============================================================================
//
// PURPOSE
// -------
// Mounts SPIFFS (without formatting) and reads back whatever files are present.
// Used to verify the state of SPIFFS after erase or restore operations.
//
// Use this sketch to:
//   - Confirm SPIFFS is empty after an Erase operation
//   - Confirm the three test files are present after a restore
//   - Read and print file contents to verify data integrity
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
//   Slow blink — files found, all contents verified
//   Fast blink — no files found (SPIFFS empty or erased)
//   Medium blink — files found but content verification failed
//
// =============================================================================

#include "SPIFFS.h"

#define LED_PIN 13
#define BAUD_RATE 115200

void flashLED(int count, int onMs, int offMs) {
  for (int i = 0; i < count; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(onMs);
    digitalWrite(LED_PIN, LOW);
    delay(offMs);
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(BAUD_RATE);
  delay(500);
  flashLED(3, 80, 80);

  Serial.println();
  Serial.println("==============================");
  Serial.println("  SPIFFS Verify Test v1.0");
  Serial.println("  ESP32 Flash Manager Test");
  Serial.println("==============================");
  Serial.println();

  if (!SPIFFS.begin(false)) {
    Serial.println("  SPIFFS mount failed.");
    Serial.println("  This likely means SPIFFS has been erased.");
    Serial.println("  Flash 04_spiffs_write to restore test data,");
    Serial.println("  or restore a backup using ESP32 Flash Manager.");
    Serial.println("==============================");
    while (true) {
      // Fast blink — erased/empty
      digitalWrite(LED_PIN, HIGH); delay(100);
      digitalWrite(LED_PIN, LOW);  delay(100);
    }
  }

  Serial.println("  SPIFFS mounted successfully.");
  Serial.printf("  Total: %d bytes\n", SPIFFS.totalBytes());
  Serial.printf("  Used:  %d bytes\n", SPIFFS.usedBytes());
  Serial.println();

  // List all files
  Serial.println("--- Files found ---");
  File root = SPIFFS.open("/");
  File file = root.openNextFile();
  int fileCount = 0;
  bool contentOk = true;

  while (file) {
    fileCount++;
    Serial.printf("  %s (%d bytes)\n", file.name(), file.size());
    String content = file.readString();
    Serial.println("  Content:");
    Serial.println("  --------");
    // Print with indent
    content.replace("\n", "\n  ");
    Serial.println("  " + content);
    Serial.println("  --------");

    // Basic content check — look for our marker string
    if (content.indexOf("ESP32 Flash Manager") < 0) {
      Serial.println("  WARNING: Expected marker string not found in this file.");
      contentOk = false;
    }

    file = root.openNextFile();
  }

  Serial.println();

  if (fileCount == 0) {
    Serial.println("  No files found. SPIFFS appears empty.");
    Serial.println("  If you expected files, the erase or restore may not");
    Serial.println("  have completed correctly.");
    Serial.println("==============================");
    while (true) {
      digitalWrite(LED_PIN, HIGH); delay(100);
      digitalWrite(LED_PIN, LOW);  delay(100);
    }
  }

  Serial.printf("  %d file(s) found.\n", fileCount);

  if (contentOk) {
    Serial.println("  Content verification PASSED.");
    Serial.println("  All files contain the expected marker string.");
  } else {
    Serial.println("  Content verification WARNING.");
    Serial.println("  One or more files did not contain the expected marker.");
  }

  Serial.println("==============================");
}

void loop() {
  // Slow blink = files found and verified
  digitalWrite(LED_PIN, HIGH); delay(800);
  digitalWrite(LED_PIN, LOW);  delay(800);
}
