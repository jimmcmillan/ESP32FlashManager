// =============================================================================
// 06_samples_write — Samples Region Write Test
// ESP32 Flash Manager test sketches
// =============================================================================
//
// PURPOSE
// -------
// Writes a known data pattern directly to the samples flash partition at
// 0x400000 using the ESP-IDF partition API. The pattern includes a header
// with a magic number, a checksum, and a fill pattern so the data can be
// verified after a backup and restore cycle.
//
// Use this sketch to:
//   - Put known, verifiable data into the samples region (0x400000)
//   - Then use the app to Read/Backup the samples region
//   - Erase the samples region using the app
//   - Flash 07_samples_verify to confirm erasure (reads 0xFF fill)
//   - Restore the samples backup using the app
//   - Flash 07_samples_verify to confirm restore (reads header back)
//
// ARDUINO IDE SETTINGS
// --------------------
//   Board:            ESP32 Dev Module
//   Flash Size:       16MB (128Mb)
//   Partition Scheme: Custom
//   Upload Speed:     921600
//   Serial Monitor:   115200 baud
//
// DATA FORMAT WRITTEN
// -------------------
//   Bytes 00-03  Magic      0x53 0x4D 0x50 0x4C ("SMPL")
//   Bytes 04-07  Version    0x01 0x00 0x00 0x00 (uint32, little-endian)
//   Bytes 08-11  DataSize   Number of fill bytes that follow header (uint32)
//   Bytes 12-15  Checksum   Sum of bytes 0-11 (uint32, little-endian)
//   Bytes 16+    Fill       0xA5 pattern (easy to spot in a hex dump)
//
// LED BEHAVIOUR
// -------------
//   3 rapid flashes on boot
//   Solid during erase and write (can take a few seconds)
//   Slow blink = write and verify passed
//   Fast blink = write or verify failed
//
// =============================================================================

#include "esp_partition.h"

#define LED_PIN 13
#define BAUD_RATE 115200

#define MAGIC_0 0x53  // 'S'
#define MAGIC_1 0x4D  // 'M'
#define MAGIC_2 0x50  // 'P'
#define MAGIC_3 0x4C  // 'L'
#define FILL_BYTE 0xA5
#define HEADER_SIZE 16
#define FILL_SIZE 1024  // 1 KB of fill pattern after header

bool allPassed = true;

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
  Serial.println("  Samples Write Test v1.0");
  Serial.println("  ESP32 Flash Manager Test");
  Serial.println("==============================");
  Serial.println();

  // Find the samples partition
  const esp_partition_t* part = esp_partition_find_first(
    ESP_PARTITION_TYPE_DATA,
    ESP_PARTITION_SUBTYPE_ANY,
    "samples"
  );

  if (part == NULL) {
    Serial.println("  FAIL: samples partition not found.");
    Serial.println("  Check that partitions.csv is in the sketch folder");
    Serial.println("  and Partition Scheme is set to Custom in Arduino IDE.");
    allPassed = false;
  } else {
    Serial.printf("  Found: samples partition at 0x%08X (%d MB)\n",
      part->address, part->size / 1048576);
    Serial.println();

    // Build header
    uint8_t header[HEADER_SIZE];
    header[0] = MAGIC_0;
    header[1] = MAGIC_1;
    header[2] = MAGIC_2;
    header[3] = MAGIC_3;
    // Version = 1
    header[4] = 0x01; header[5] = 0x00; header[6] = 0x00; header[7] = 0x00;
    // DataSize = FILL_SIZE
    header[8]  = (FILL_SIZE)       & 0xFF;
    header[9]  = (FILL_SIZE >> 8)  & 0xFF;
    header[10] = (FILL_SIZE >> 16) & 0xFF;
    header[11] = (FILL_SIZE >> 24) & 0xFF;
    // Checksum = sum of bytes 0-11
    uint32_t cksum = 0;
    for (int i = 0; i < 12; i++) cksum += header[i];
    header[12] = (cksum)       & 0xFF;
    header[13] = (cksum >> 8)  & 0xFF;
    header[14] = (cksum >> 16) & 0xFF;
    header[15] = (cksum >> 24) & 0xFF;

    // Fill buffer
    uint8_t fill[FILL_SIZE];
    memset(fill, FILL_BYTE, FILL_SIZE);

    // Erase the first sector (4096 bytes minimum erase unit)
    Serial.println("--- Erasing first sector ---");
    digitalWrite(LED_PIN, HIGH);
    esp_err_t err = esp_partition_erase_range(part, 0, 4096);
    if (err != ESP_OK) {
      Serial.printf("  FAIL: Erase error 0x%X\n", err);
      allPassed = false;
    } else {
      Serial.println("  OK: Sector erased.");
    }

    // Write header
    Serial.println("--- Writing header ---");
    err = esp_partition_write(part, 0, header, HEADER_SIZE);
    if (err != ESP_OK) {
      Serial.printf("  FAIL: Header write error 0x%X\n", err);
      allPassed = false;
    } else {
      Serial.println("  OK: Header written.");
    }

    // Write fill
    Serial.println("--- Writing fill pattern ---");
    err = esp_partition_write(part, HEADER_SIZE, fill, FILL_SIZE);
    if (err != ESP_OK) {
      Serial.printf("  FAIL: Fill write error 0x%X\n", err);
      allPassed = false;
    } else {
      Serial.printf("  OK: %d bytes of 0xA5 fill written.\n", FILL_SIZE);
    }

    // Verify by reading back
    Serial.println("--- Verifying ---");
    uint8_t readBuf[HEADER_SIZE];
    err = esp_partition_read(part, 0, readBuf, HEADER_SIZE);
    if (err != ESP_OK) {
      Serial.printf("  FAIL: Read error 0x%X\n", err);
      allPassed = false;
    } else {
      bool magicOk = (readBuf[0] == MAGIC_0 && readBuf[1] == MAGIC_1 &&
                      readBuf[2] == MAGIC_2 && readBuf[3] == MAGIC_3);
      if (magicOk) {
        Serial.println("  PASS: Magic bytes verified (SMPL).");
      } else {
        Serial.printf("  FAIL: Magic mismatch: %02X %02X %02X %02X\n",
          readBuf[0], readBuf[1], readBuf[2], readBuf[3]);
        allPassed = false;
      }
    }

    digitalWrite(LED_PIN, LOW);

    Serial.println();
    Serial.println("--- Hex dump of first 32 bytes ---");
    uint8_t dump[32];
    esp_partition_read(part, 0, dump, 32);
    for (int i = 0; i < 32; i++) {
      Serial.printf("%02X ", dump[i]);
      if ((i + 1) % 16 == 0) Serial.println();
    }
    Serial.println();
  }

  if (allPassed) {
    Serial.println("  ALL TESTS PASSED.");
    Serial.println("  You can now use ESP32 Flash Manager to:");
    Serial.println("  1. Read/Backup the samples region (0x400000)");
    Serial.println("  2. Erase the samples region");
    Serial.println("  3. Flash 07_samples_verify — should show 0xFF fill");
    Serial.println("  4. Restore the samples backup");
    Serial.println("  5. Flash 07_samples_verify — should show SMPL header");
  } else {
    Serial.println("  ONE OR MORE TESTS FAILED.");
  }

  Serial.println("==============================");
}

void loop() {
  if (allPassed) {
    digitalWrite(LED_PIN, HIGH); delay(800);
    digitalWrite(LED_PIN, LOW);  delay(800);
  } else {
    digitalWrite(LED_PIN, HIGH); delay(100);
    digitalWrite(LED_PIN, LOW);  delay(100);
  }
}
