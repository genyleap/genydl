## GenyDL ⚡️

**Next-Gen, Ultra-Fast, and Reliable Download Manager**

GenyDL is a modern, high-performance download manager built with **C++23**, **Qt 6**, and **QML**, designed for speed, reliability, clean architecture, and a polished desktop experience — featuring built-in support for the **Geny blockchain ecosystem**, IPFS, and BitTorrent networks.
<img width="1600" height="640" alt="background" src="https://github.com/user-attachments/assets/13261f2a-4a8e-4f1b-be27-9afe84990bfd" />

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![C++](https://img.shields.io/badge/C%2B%2B%20Version-23-blue.svg)
![Qt](https://img.shields.io/badge/Qt-6.8%2B-brightgreen.svg)

### Browser extensions

<a href="https://addons.mozilla.org/en-US/firefox/addon/genydl-download-with-genydl/"><img src="docs/assets/store-badges/firefox-get-the-addon.svg" alt="Get the GenyDL add-on for Firefox" width="172" height="60"></a>

Chrome and Opera: [install via Developer Mode](#browser-add-ons) · Store publication pending.

## 🚧 Project Status

> GenyDL is currently under active development.  
> Version **1.0.0** is the first milestone release, focused on the desktop UI, core download workflow, packaging, and runtime foundation.

## Highlights

- Modern QML-based desktop interface
- Multi-segment download engine foundation
- Torrent and magnet backend support for P2P downloads
- Geny blockchain ecosystem and IPFS networking integration
- Built-in Application Store (Release Center) for seamless updates
- Resume, pause, retry, cancel, and remove actions
- Per-segment progress and download details window
- Queue and category-based download organization
- Adaptive segment controller foundation
- Per-task and global speed limit foundation
- Proxy, SSL, User-Agent, and network configuration foundation
- Runtime dashboard for CPU, memory, disk, network, and transfer status
- URL probe, advanced GitHub, and IPFS-based update client
- Session persistence, import/export, and post-download action foundation
- Cross-platform packaging for macOS and Windows
- Browser integration with Firefox, Chrome and Opera; manual link review by default and optional automatic capture.

## Browser add-ons

Send a link directly to GenyDL using the extension popup or the **Download with GenyDL** context menu. The desktop review dialog remains the default. Ask/Always capture is optional and requires explicit browser permission.

| Browser | Availability | Get the extension |
| --- | --- | --- |
| Firefox | Published on Mozilla Add-ons (1.3.3) | [Install from Mozilla Add-ons](https://addons.mozilla.org/en-US/firefox/addon/genydl-download-with-genydl/) |
| Chrome | Unpacked package; store publication pending | Configuration → Browsers → Chrome → Open extension folder |
| Opera | Unpacked package; store publication pending, real-browser verification pending | Configuration → Browsers → Opera → Open extension folder |

Launch GenyDL, enable the desired browser under **Configuration → Browsers**, then install the extension. For Chrome and Opera, open the browser's extension manager, enable Developer mode and select **Load unpacked** (or **Load Extension**) using the folder exported by GenyDL. A green check confirms a recent Native Messaging response, not just registration.

To build the standalone add-on ZIPs from source (without compiling the desktop application):

```sh
cmake --build build --target browser-extension-zip
```

Use an already configured build directory; the output files are `GenyDL-Firefox-extension.zip`, `GenyDL-Chrome-extension.zip` and `GenyDL-Opera-extension.zip`. Unpacked users must extract ZIPs before loading. These are not signed store packages. For Opera Add-ons submission, use the separate `GenyDL-Opera-store.zip` (without the development key); see the store submission guide below.

[Installation and troubleshooting](docs/browser-integration.md) · [Store submission guide](docs/browser-store-publication.md)

## Planned Features

- Speed and network tester module
- Auto platform and file type detector
- Stream and social media download support
- More advanced mirror failover and checksum verification workflows

## Shots
<img width="1302" height="850" alt="Screenshot 2026-06-12 at 00 50 38" src="https://github.com/user-attachments/assets/9a2117fb-25e7-4a54-abec-6e111e5bbb3e" />
<img width="1298" height="847" alt="Screenshot 2026-06-12 at 00 50 49" src="https://github.com/user-attachments/assets/3195ae45-e3b6-4af6-a1a2-a54b9aa510bf" />


## Tech Stack

- C++23
- CMake 3.28+
- Qt 6.8+
- Qt Quick / QML
- Qt Core, Network, Concurrent, Gui, Quick, QuickControls2
- C++20 Modules

## Requirements

- CMake 3.28+
- Qt 6.8+
- A C++23-capable compiler
- For C++ modules:
  - LLVM Clang + `clang-scan-deps` on macOS/Linux
  - MSVC 2022 on Windows

## Build

### macOS / Linux

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

If GenyDL helps you, consider supporting its continued development.

## Crypto Donations
GENY / ETH (ERC20)
```0x6E99f7564d060AA141dcC47ede34379Bad0cDCCC```
BTC
```BC1Q2Q7G83V9UXATK0YSPFVCU3YDNMESEU3Y7P9J9N```

Your support keeps the project alive and evolving.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
