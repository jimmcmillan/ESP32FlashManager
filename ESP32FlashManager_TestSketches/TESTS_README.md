# ESP32 Flash Manager: Test Sketches

A set of Arduino sketches for testing all features of ESP32 Flash Manager.
Run these sketches in order to verify every app operation against a real device.

---

## Arduino IDE Settings

These settings apply to all sketches. Check them every time before uploading.

| Setting | Value |
|---|---|
| Board | ESP32 Dev Module |
| Flash Size | 16MB (128Mb) |
| Partition Scheme | Custom |
| Upload Speed | 921600 |
| Serial Monitor | 115200 baud |

> **Important:** Always confirm Flash Size is set to 16MB before uploading.
> Uploading with an incorrect Flash Size will write a bad partition table and
> cause the board to boot loop. If this happens, simply re-upload any sketch
> with the correct 16MB setting to recover.

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

## Full Test Procedure

Run through these steps in order to test every feature of ESP32 Flash Manager.
The entire procedure covers firmware flashing, region backup, erase, restore,
and full board restore.

---

### Stage 1: Firmware Region (app0 at 0x010000)

Tests: Flash Region, Read/Backup, Restore

**Step 1.** Open `01_blink_a` in Arduino IDE and upload to the board.
Confirm the LED blinks slowly (1 Hz).

**Step 2.** In ESP32 Flash Manager, select the `app0` region and use
**Read/Backup** to save a backup of the firmware. Save the file somewhere safe.

**Step 3.** Open `02_blink_b` in Arduino IDE and upload to the board.
Confirm the LED blinks fast (5 Hz). This confirms a new firmware is running.

**Step 4.** In ESP32 Flash Manager, select the `app0` region and use
**Flash Region** to restore the Firmware A backup saved in Step 2.
The board will reboot automatically.

**Step 5.** Confirm the LED returns to slow blink (1 Hz).
Firmware restore is working.

---

### Stage 2: Device Info Verification (app0 at 0x010000)

Tests: Device detection, Device Info screen, partition table display

**Step 6.** Open `03_chip_info` in Arduino IDE and upload to the board.
Open Serial Monitor at 115200 baud.

**Step 7.** The sketch prints full chip information and the complete partition
table. Cross-check this output against what ESP32 Flash Manager shows in the
Device Info and Overview screens. Region names, addresses, and sizes should
match exactly.

---

### Stage 3: SPIFFS Region (0x210000)

Tests: Read/Backup, Erase Region, Flash Region (restore)

**Step 8.** Open `04_spiffs_write` in Arduino IDE and upload to the board.
The sketch formats SPIFFS, writes three test files, then reads them back.
Confirm the LED blinks slowly (all passed). Fast blink means a failure.

**Step 9.** In ESP32 Flash Manager, select the `spiffs` region and use
**Read/Backup** to save a backup. This captures the three test files.

**Step 10.** In ESP32 Flash Manager, select the `spiffs` region and use
**Erase Region**.

**Step 11.** Open `05_spiffs_verify` in Arduino IDE and upload to the board.
Confirm the LED blinks fast — this means SPIFFS is empty, confirming the
erase worked.

**Step 12.** In ESP32 Flash Manager, select the `spiffs` region and use
**Flash Region** to restore the SPIFFS backup saved in Step 9.

**Step 13.** Upload `05_spiffs_verify` again.
Confirm the LED returns to slow blink — the three test files are back,
confirming the restore worked.

---

### Stage 4: Samples Region (0x400000)

Tests: Read/Backup, Erase Region, Flash Region (restore)

**Step 14.** Open `06_samples_write` in Arduino IDE and upload to the board.
The sketch writes a known `SMPL` header and `0xA5` fill pattern to the samples
partition. Confirm the LED blinks slowly (passed). Fast blink means a failure.

**Step 15.** In ESP32 Flash Manager, select the `samples` region and use
**Read/Backup** to save a backup.

**Step 16.** In ESP32 Flash Manager, select the `samples` region and use
**Erase Region**.

**Step 17.** Open `07_samples_verify` in Arduino IDE and upload to the board.
Open Serial Monitor at 115200 baud. Confirm the first 64 bytes are all `FF` —
this confirms the erase worked. The LED should blink fast.

Expected Serial output after erase:
```
FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
...
All 0xFF — region is erased.
```

**Step 18.** In ESP32 Flash Manager, select the `samples` region and use
**Flash Region** to restore the samples backup saved in Step 15.

**Step 19.** Upload `07_samples_verify` again.
Confirm the Serial Monitor shows the `SMPL` header (`53 4D 50 4C`) and the
`A5` fill pattern. The LED should blink slowly.

Expected Serial output after restore:
```
53 4D 50 4C 01 00 00 00 00 04 00 00 41 01 00 00
A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5 A5
...
SMPL magic header found.
Restore was successful.
```

---

### Stage 5: Full Board Restore

Tests: Full Board Restore (writes merged .bin from 0x00000000)

**Step 20.** Open `08_full_board_a` in Arduino IDE and upload to the board.
Confirm the LED blinks in an SOS pattern (... --- ...).

**Step 21.** With `08_full_board_a` still open in Arduino IDE, go to
**Sketch → Export Compiled Binary**. Find the file ending in
`.ino.merged.bin` in the sketch's `build/` folder. This is the Full Board A
binary.

**Step 22.** Open `09_full_board_b` in Arduino IDE and upload to the board.
Confirm the LED blinks in a heartbeat pattern (two quick pulses, long pause).

> **Note:** After uploading, the board may blink once and pause before the
> pattern begins. Press the reset button for a clean boot if needed.

**Step 23.** With `09_full_board_b` still open, go to
**Sketch → Export Compiled Binary** and grab the `.ino.merged.bin` for
Full Board B.

**Step 24.** In ESP32 Flash Manager, use **Full Board Restore** and select
the Full Board A `.ino.merged.bin` from Step 21.
The board will reboot automatically. Confirm the SOS pattern returns.

**Step 25.** In ESP32 Flash Manager, use **Full Board Restore** and select
the Full Board B `.ino.merged.bin` from Step 23.
The board will reboot automatically. Confirm the heartbeat pattern returns.

Full Board Restore is working.

---

## All Tests Passed

If all 25 steps completed successfully, every major feature of ESP32 Flash
Manager has been verified against real hardware:

| Feature | Stage | Result |
|---|---|---|
| Flash Region (firmware) | Stage 1 | ✓ |
| Read/Backup (firmware) | Stage 1 | ✓ |
| Device Info / partition table display | Stage 2 | ✓ |
| Read/Backup (SPIFFS) | Stage 3 | ✓ |
| Erase Region (SPIFFS) | Stage 3 | ✓ |
| Flash Region (SPIFFS restore) | Stage 3 | ✓ |
| Read/Backup (samples) | Stage 4 | ✓ |
| Erase Region (samples) | Stage 4 | ✓ |
| Flash Region (samples restore) | Stage 4 | ✓ |
| Full Board Restore | Stage 5 | ✓ |

---

## Sketch Reference

| Sketch | Purpose | LED |
|---|---|---|
| 01_blink_a | Firmware A baseline | Slow blink (1 Hz) |
| 02_blink_b | Firmware B for restore testing | Fast blink (5 Hz) |
| 03_chip_info | Chip and partition info reporter | Slow pulse |
| 04_spiffs_write | Write known files to SPIFFS | Slow = pass, Fast = fail |
| 05_spiffs_verify | Verify SPIFFS contents | Slow = files found, Fast = empty |
| 06_samples_write | Write known pattern to samples | Slow = pass, Fast = fail |
| 07_samples_verify | Verify samples contents | Slow = header found, Fast = empty |
| 08_full_board_a | Full board restore test A | SOS pattern |
| 09_full_board_b | Full board restore test B | Heartbeat pattern |

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
