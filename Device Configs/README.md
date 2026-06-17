# Device Configs

## Contents

- [How it works](#how-it-works)
- [How to load a config file](#how-to-load-a-config-file)
- [Creating a config for another device](#creating-a-config-for-another-device)
- [Available configs](#available-configs)
  - [Phonicbloom MMXX T-APE](#phonicbloom-mmxx-t-ape)
- [Credits](#credits)
- [Contributing](#contributing)

---

## How it works

This folder contains JSON configuration files for specific devices that work with the ESP32 Flash Manager.

By default, the ESP32 Flash Manager reads the partition table directly from the connected device and automatically displays all detected regions by their raw technical names and addresses, but gives you a generic view.

A device config file replaces that generic view with a layout tailored to a specific device. Each region gets a plain name, a description explaining what it is and what you should or should not do with it, and a defined set of permitted operations. Regions that should not be written to are set to read only, so the relevant buttons do not appear.

Loading a config file does not change anything on the device. It only changes how the app presents the device to you.

---

## How to load a config file

1. Open ESP32 Flash Manager and connect your device.
2. Click **Device configs** in the left sidebar.
3. Click **Import config** and select the JSON file for your device.
4. The app will confirm the config is loaded with the device name shown under Active Config.

To go back to the generic view at any time, click **Clear config** in the same panel.

---

## Creating a config for another device

Use the Export template button in the Device configs panel to get a blank template JSON file. Fill in the device details and define your regions following the same structure as the files in this folder.

The required fields for each region are `id`, `name`, `address`, `size`, and `operations`. The `description` field is optional but strongly recommended. Valid operation values are `read`, `write` and `erase`.

The `chip_model` field in the device section must match exactly what esptool reports for your chip when it connects. You can find this in the console output after clicking Detect device.

---

## Available configs

### Phonicbloom MMXX T-APE

**File:** `mmxx_tape.json`
**Chip:** ESP32-PICO-D4
**Flash:** 16 MB

The MMXX T-APE is a bytebeat synthesiser made by Phonicbloom. This config gives each flash region a clear label and description, restricts dangerous regions to read-only, and splits the sample memory into two named areas that reflect how the firmware uses them.

#### Regions

| Name | Address | Size | Operations |
|---|---|---|---|
| Bootloader | 0x001000 | 28 KB | Read |
| Partition Table | 0x008000 | 4 KB | Read |
| NVS Boot Storage | 0x009000 | 80 KB | Read |
| OTA Data | 0x01D000 | 8 KB | Read |
| Radio Calibration | 0x01F000 | 4 KB | Read |
| Device Config | 0x020000 | 64 KB | Read |
| **Patches** (Your Saved Sounds) | 0x030000 | 416 KB | Read, Write |
| Factory Patch Defaults | 0x098000 | 416 KB | Read |
| **Firmware** | 0x100000 | 1 MB | Read, Write |
| Factory Samples | 0x200000 | 1 MB | Read |
| **User Samples** | 0x300000 | 1 MB | Read, Write |

#### Notes on the T-APE memory layout

**Patches** (0x030000) is the active patch bank. All 64 patches the user saves on the device are stored here, arranged in 8 banks of 8.

**Factory Patch Defaults** (0x098000) is a separate, protected copy of the original factory patches written at the time of manufacture. It is read-only.

**Firmware** (0x100000) is the main application firmware. It is completely separate from the sample and patch regions. Updating the firmware does not affect patches or samples.

**Factory Samples** (0x200000) holds the 8 audio samples that ship with the T-APE. The firmware maps this region directly into memory for playback using hardcoded offsets compiled into the firmware. This region is read-only.

**User Samples** (0x300000) is a 1 MB area reserved for custom audio samples. It is separate from the factory sample region, so uploading custom samples here does not overwrite the original samples. Note that custom sample playback from this region is not yet implemented in the current firmware.

---

## Credits

- MMXX T-APE hardware and firmware by Phonicbloom https://phonicbloom.com/tape/
- Firmware source: https://github.com/h3o/bsafe
- Memory reference derived from analysis of the firmware source code
- App built with Xcode, Swift and SwiftUI

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

---

## Acknowledgements

- [esptool](https://github.com/espressif/esptool) by Espressif Systems — used as a bundled subprocess for all device communication
- ESP32 partition table binary format — [Espressif documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/partition-tables.html)
