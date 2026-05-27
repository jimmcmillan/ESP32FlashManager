// =============================================================================
// 03_chip_info — Chip and Partition Info Reporter
// ESP32 Flash Manager test sketches
// =============================================================================
//
// PURPOSE
// -------
// Prints full chip information and the complete partition table to Serial
// on boot. Used to verify device detection, cross-check what the app reports
// against what the hardware actually reports, and confirm partition layout
// after any flash or restore operation.
//
// Use this sketch to:
//   - Verify the partition table shown in the app matches the device
//   - Confirm flash size, chip model, MAC, revision
//   - Cross-check region addresses and sizes
//   - Sanity check after a full board restore
//
// ARDUINO IDE SETTINGS
// --------------------
//   Board:            ESP32 Dev Module
//   Flash Size:       16MB (128Mb)
//   Partition Scheme: Custom
//   Upload Speed:     921600
//   Serial Monitor:   115200 baud
//
// =============================================================================

#include "esp_partition.h"
#include "esp_chip_info.h"
#include "esp_flash.h"
#include "WiFi.h"

#define BAUD_RATE 115200
#define LED_PIN 13

void setup() {
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(BAUD_RATE);
  delay(1000);

  Serial.println();
  Serial.println("==============================");
  Serial.println("  Chip Info Reporter v1.0");
  Serial.println("  ESP32 Flash Manager Test");
  Serial.println("==============================");
  Serial.println();

  // --- Chip Info ---
  esp_chip_info_t chip;
  esp_chip_info(&chip);

  Serial.println("--- Chip ---");
  Serial.printf("  Model:     ESP32\n");
  Serial.printf("  Revision:  %d\n", chip.revision);
  Serial.printf("  Cores:     %d\n", chip.cores);
  Serial.printf("  CPU Freq:  %d MHz\n", getCpuFrequencyMhz());
  Serial.printf("  Free Heap: %d bytes\n", ESP.getFreeHeap());
  Serial.println();

  // --- MAC ---
  uint8_t mac[6];
  WiFi.mode(WIFI_STA);
  delay(100);
  Serial.println("--- Network ---");
  Serial.printf("  MAC: %s\n", WiFi.macAddress().c_str());
  Serial.println();

  // --- Flash ---
  uint32_t flashSize = 0;
  esp_flash_get_size(NULL, &flashSize);
  Serial.println("--- Flash ---");
  Serial.printf("  Size:  %d bytes (%d MB)\n", flashSize, flashSize / 1048576);
  Serial.printf("  Speed: %d Hz\n", ESP.getFlashChipSpeed());
  Serial.println();

  // --- Partition Table ---
  Serial.println("--- Partition Table ---");
  Serial.println("  Name      | Type | SubType  | Offset     | Size");
  Serial.println("  ----------|------|----------|------------|------------------");

  esp_partition_iterator_t it = esp_partition_find(
    ESP_PARTITION_TYPE_ANY,
    ESP_PARTITION_SUBTYPE_ANY,
    NULL
  );

  while (it != NULL) {
    const esp_partition_t* p = esp_partition_get(it);

    char typeName[16];
    if (p->type == ESP_PARTITION_TYPE_APP) strcpy(typeName, "app ");
    else strcpy(typeName, "data");

    char subTypeName[16];
    switch (p->subtype) {
      case ESP_PARTITION_SUBTYPE_APP_OTA_0:   strcpy(subTypeName, "ota_0   "); break;
      case ESP_PARTITION_SUBTYPE_APP_OTA_1:   strcpy(subTypeName, "ota_1   "); break;
      case ESP_PARTITION_SUBTYPE_DATA_NVS:    strcpy(subTypeName, "nvs     "); break;
      case ESP_PARTITION_SUBTYPE_DATA_OTA:    strcpy(subTypeName, "ota     "); break;
      case ESP_PARTITION_SUBTYPE_DATA_SPIFFS: strcpy(subTypeName, "spiffs  "); break;
      case 0xff:                              strcpy(subTypeName, "0xff    "); break;
      default:
        sprintf(subTypeName, "0x%02X    ", p->subtype);
    }

    Serial.printf("  %-9s| %s | %s | 0x%08X | 0x%08X (%4d KB)\n",
      p->label,
      typeName,
      subTypeName,
      p->address,
      p->size,
      p->size / 1024
    );

    it = esp_partition_next(it);
  }
  esp_partition_iterator_release(it);

  Serial.println();
  Serial.println("==============================");
  Serial.println("  Report complete.");
  Serial.println("  Reset to run again.");
  Serial.println("==============================");

  // Slow steady pulse to show sketch is running
  while (true) {
    digitalWrite(LED_PIN, HIGH);
    delay(1000);
    digitalWrite(LED_PIN, LOW);
    delay(1000);
  }
}

void loop() {}
