// =============================================================================
// 07_samples_verify — Samples Region Verify Test
// ESP32 Flash Manager test sketches
// =============================================================================
//
// PURPOSE
// -------
// Reads the first 64 bytes of the samples partition and reports what it finds.
// Used to verify the state of the samples region after erase or restore.
//
// Use this sketch to:
//   - Confirm samples region is erased (reads 0xFF fill)
//   - Confirm samples backup was restored (reads SMPL header)
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
//   3 rapid flashes on boot
//   Slow blink  = SMPL header found (data present, restore successful)
//   Fast blink  = 0xFF fill found (region erased)
//   Medium blink = unexpected data (neither erased nor known header)
//
// =============================================================================

#include "esp_partition.h"

#define LED_PIN 13
#define BAUD_RATE 115200

void flashLED(int count, int onMs, int offMs) {
  for (int i = 0; i < count; i++) {
    digitalWrite(LED_PIN, HIGH); delay(onMs);
    digitalWrite(LED_PIN, LOW);  delay(offMs);
  }
}

void setup() {
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(BAUD_RATE);
  delay(500);
  flashLED(3, 80, 80);

  Serial.println();
  Serial.println("==============================");
  Serial.println("  Samples Verify Test v1.0");
  Serial.println("  ESP32 Flash Manager Test");
  Serial.println("==============================");
  Serial.println();

  const esp_partition_t* part = esp_partition_find_first(
    ESP_PARTITION_TYPE_DATA,
    ESP_PARTITION_SUBTYPE_ANY,
    "samples"
  );

  if (part == NULL) {
    Serial.println("  FAIL: samples partition not found.");
    Serial.println("  Check partitions.csv and Partition Scheme setting.");
    Serial.println("==============================");
    while (true) {
      digitalWrite(LED_PIN, HIGH); delay(200);
      digitalWrite(LED_PIN, LOW);  delay(200);
    }
  }

  Serial.printf("  Found: samples at 0x%08X (%d MB)\n",
    part->address, part->size / 1048576);
  Serial.println();

  // Read first 64 bytes
  uint8_t buf[64];
  esp_err_t err = esp_partition_read(part, 0, buf, 64);
  if (err != ESP_OK) {
    Serial.printf("  FAIL: Read error 0x%X\n", err);
    Serial.println("==============================");
    while (true) {
      digitalWrite(LED_PIN, HIGH); delay(200);
      digitalWrite(LED_PIN, LOW);  delay(200);
    }
  }

  // Hex dump
  Serial.println("--- First 64 bytes ---");
  for (int i = 0; i < 64; i++) {
    Serial.printf("%02X ", buf[i]);
    if ((i + 1) % 16 == 0) Serial.println();
  }
  Serial.println();

  // Interpret what we found
  bool hasMagic = (buf[0] == 0x53 && buf[1] == 0x4D &&
                   buf[2] == 0x50 && buf[3] == 0x4C);
  bool isErased = true;
  for (int i = 0; i < 64; i++) {
    if (buf[i] != 0xFF) { isErased = false; break; }
  }

  Serial.println("--- Result ---");

  if (hasMagic) {
    Serial.println("  SMPL magic header found.");
    Serial.println("  The samples region contains test data from 06_samples_write.");
    Serial.println("  Restore was successful (or erase has not been run yet).");
    Serial.println("==============================");
    while (true) {
      // Slow blink = data present
      digitalWrite(LED_PIN, HIGH); delay(800);
      digitalWrite(LED_PIN, LOW);  delay(800);
    }
  } else if (isErased) {
    Serial.println("  All 0xFF — region is erased.");
    Serial.println("  Erase operation confirmed successful.");
    Serial.println("  Restore a backup to put data back.");
    Serial.println("==============================");
    while (true) {
      // Fast blink = erased
      digitalWrite(LED_PIN, HIGH); delay(100);
      digitalWrite(LED_PIN, LOW);  delay(100);
    }
  } else {
    Serial.println("  Unexpected data — neither SMPL header nor 0xFF fill.");
    Serial.println("  First 4 bytes: " +
      String(buf[0], HEX) + " " + String(buf[1], HEX) + " " +
      String(buf[2], HEX) + " " + String(buf[3], HEX));
    Serial.println("==============================");
    while (true) {
      // Medium blink = unknown
      digitalWrite(LED_PIN, HIGH); delay(300);
      digitalWrite(LED_PIN, LOW);  delay(300);
    }
  }
}

void loop() {}
