# ESP32 Flash Manager — Test Sketches

A set of Arduino sketches for testing all features of ESP32 Flash Manager.
Each sketch is designed to test a specific operation or region of the flash.

---

## Arduino IDE Settings

These settings apply to all sketches:

| Setting | Value |
|---|---|
| Board | ESP32 Dev Module |
| Flash Size | 16MB (128Mb) |
| Partition Scheme | Custom |
| Upload Speed | 921600 |
| Serial Monitor | 115200 baud |

Each sketch folder contains a `partitions.csv` file. When Partition Scheme is
set to Custom, Arduino IDE automatically uses this file from the sketch folder.

---

## Partition Layout

All sketches use this layout:

| Region | Address | Size | Purpose |
|---|---|---|---|
| nvs | 0x009000 | 20 KB | Non-volatile storage |
| otadata | 0x00E000 | 8 KB | OTA slot selector |
| app0 | 0x010000 | 2 MB | Firmware |
| spiffs | 0x210000 | 2 MB | File storage |
| samples | 0x400000 | 8 MB | Raw sample data |

---

## Sketches

### 01: Firmware Test A
**Tests:** Flash region, Read/Backup (app0 at 0x10000)
**LED:** Slow blink (1 Hz)
Upload this first. Back it up. Flash Firmware B over it. Restore and confirm
the slow blink returns.

---

### 02: Firmware Test B
**Tests:** Flash region, restore verification (app0 at 0x10000)
**LED:** Fast blink (5 Hz)
Flash this over Firmware A to confirm the write worked. Restore the Firmware A
backup and confirm the LED returns to slow blink.

**Test workflow:**
1. Upload 01_blink_a via Arduino IDE — slow blink confirmed
2. Use app Read/Backup to save app0 region
3. Upload 02_blink_b via Arduino IDE — fast blink confirmed
4. Use app Flash Region to restore the Firmware A backup to app0
5. Board reboots — slow blink should return

---

### 03: Chip Info Reporter
**Tests:** Device detection, Device Info screen verification
**LED:** Slow steady pulse while running
Prints full chip info and partition table to Serial Monitor. Cross-check the
output against what ESP32 Flash Manager shows in the Device Info and Overview
screens.

---

### 04: SPIFFS Write Test
**Tests:** SPIFFS region write, backup preparation (0x210000)
**LED:** Slow blink = passed, Fast blink = failed
Formats SPIFFS, writes three test files, reads them back. Run this before
backing up SPIFFS so there is known data to verify after a restore.

**Test workflow:**
1. Upload 04_spiffs_write — confirm slow blink (all passed)
2. Use app Read/Backup to save the SPIFFS region (0x210000)
3. Use app Erase Region on SPIFFS
4. Upload 05_spiffs_verify — fast blink confirms SPIFFS is empty
5. Use app Flash Region to restore the SPIFFS backup
6. Upload 05_spiffs_verify — slow blink confirms files are back

---

### 05: SPIFFS Verify Test
**Tests:** SPIFFS erase confirmation, restore verification
**LED:** Slow blink = files found, Fast blink = empty/erased
Mounts SPIFFS without formatting and reads whatever files are present.
Use after erase (expect fast blink) and after restore (expect slow blink).

---

### 06: Samples Write Test
**Tests:** Samples region write, backup preparation (0x400000)
**LED:** Slow blink = passed, Fast blink = failed
Writes a known SMPL header and 0xA5 fill pattern to the samples partition
using the ESP-IDF partition API. Run this before backing up the samples region.

**Test workflow:**
1. Upload 06_samples_write — confirm slow blink (all passed)
2. Use app Read/Backup to save the samples region (0x400000)
3. Use app Erase Region on samples
4. Upload 07_samples_verify — fast blink confirms region is erased (0xFF)
5. Use app Flash Region to restore the samples backup
6. Upload 07_samples_verify — slow blink confirms SMPL header is back

---

### 07: Samples Verify Test
**Tests:** Samples erase confirmation, restore verification
**LED:** Slow blink = SMPL header found, Fast blink = erased (0xFF), Medium blink = unexpected data
Reads the first 64 bytes of the samples partition and prints a hex dump.
Use after erase (expect fast blink) and after restore (expect slow blink).

---

### 08: Full Board Test A
**Tests:** Full Board Restore (writes from 0x00000000)
**LED:** SOS pattern (... --- ...)
One of two sketches for testing the full board restore feature.
Export the merged .bin from Arduino IDE and use it as the restore source.

**To export a merged .bin:**
In Arduino IDE with this sketch open:
Sketch → Export Compiled Binary
Find the file ending in `.ino.merged.bin` in the sketch's `build/` folder.
This is the file to use with ESP32 Flash Manager Restore Backup.

**Test workflow:**
1. Upload 08_full_board_a — SOS pattern confirmed
2. Export merged .bin of Full Board A
3. Upload 09_full_board_b — heartbeat pattern confirmed
4. Export merged .bin of Full Board B
5. Use app Restore Backup with Full Board A merged .bin
6. Board reboots — SOS pattern should return
7. Use app Restore Backup with Full Board B merged .bin
8. Board reboots — heartbeat pattern should return

---

### 09 — Full Board Test B
**Tests:** Full Board Restore (writes from 0x00000000)
**LED:** Heartbeat pattern (two quick pulses, long pause)
Companion to Full Board Test A. See workflow above.

---

## Quick Reference — Which sketch tests what

| App Feature | Sketches to use |
|---|---|
| Flash Region (app0) | 01 and 02 |
| Read/Backup (app0) | 01 then 02 to verify |
| Erase Region (SPIFFS) | 04 to write, 05 to verify after erase |
| Flash Region (SPIFFS restore) | 04 to write, 05 to verify after restore |
| Erase Region (samples) | 06 to write, 07 to verify after erase |
| Flash Region (samples restore) | 06 to write, 07 to verify after restore |
| Device Info screen | 03 |
| Full Board Restore | 08 and 09 merged .bin files |
| Read/Backup (SPIFFS) | 04 to write, restore and verify with 05 |
| Read/Backup (samples) | 06 to write, restore and verify with 07 |

---

## Support, Contributions and Disclaimer

**This project is provided as-is.**

It is test software, shared publicly for reference. It is not actively maintained.

- **Issues and bug reports** will not be monitored or responded to
- **Pull requests and contributions** will not be accepted
- **Forks are welcome**

**Use entirely at your own risk.**

Flashing firmware to hardware carries an inherent risk of rendering a device inoperable if something goes wrong. The author accepts no responsibility for damage to hardware, data loss, voided warranties, or any other consequence arising from the use of this software, the source code, or the firmware files in this repository.

This software is provided without warranty of any kind, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, or non-infringement.

**By using this software you accept these terms in full.**