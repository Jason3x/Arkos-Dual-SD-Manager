## ArkOS Dual SD Manager
![Platform](https://img.shields.io/badge/Platform-R36S-blue)
![OS](https://img.shields.io/badge/OS-ArkOS%20|%20dArkOS-green)
![Shell](https://img.shields.io/badge/Bash-Script-yellow)
![License](https://img.shields.io/badge/License-Free-lightgrey)

ArkOS Dual SD Manager is a Bash script designed for ArkOS that allows easy dual SD card management.

The script automatically detects the presence of a second SD card and merges the ROM folders so the system can use both cards as a single library.

It also provides automatic save synchronization between the two cards.

---

## ✨ Features
- Automatic external SD card detection

- Automatic save synchronization for:
`.srm`<br> `.sav`<br> `.state*`<br> `.png`<br> `.cfg`<br> `.ini`<br> `.json`<br> `.dat`<br> `.bin`<br> `*.save`<br> `*save*/**`<br> `*Save*/**`

- The script automatically syncs save files in both directions (This ensures your progress is never lost when switching or removing the external SD card.) :<br>`SD2 → SD1`<br> `SD1 → SD2`<br>  

- Automatic switching between:
`Internal SD only mode`<br> `Dual SD mode`<br>

  
- Automatic EmulationStation restart when needed.
  
- The background service checks the SD card status every 10 seconds.

## 📋 Requirements

- Internet connection (first-time install only)
- Supported SD2 card format: `exFAT`, `FAT32`
- The `tools` and `themes` folders are required.
- ArkOS system folder are required for games 
  
---

## 🚀 Installation
 
1. Download the `ArkOS Dual SD Manager.sh` script.
2. Copy it to one of the following directories: `roms/tools`
3. Launch it from the Tools section on your device.

---

## ☕ A coffee to support the project?

[![Ko-fi](https://img.shields.io/badge/☕_Buy_me_a_coffee-jason3x-red?style=for-the-badge)](https://ko-fi.com/jason3x)
