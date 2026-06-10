## GenyDL ⚡️

**Next-Gen, Ultra-Fast, and Reliable Download Manager**

GenyDL is a modern, high-performance download manager built with **C++23**, **Qt 6**, and **QML**, designed for speed, reliability, clean architecture, and a polished desktop experience — with future integration for the **Geny token ecosystem** and blockchain-powered features.

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![C++](https://img.shields.io/badge/C%2B%2B%20Version-23-blue.svg)
![Qt](https://img.shields.io/badge/Qt-6.8%2B-brightgreen.svg)
![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen.svg)

## 🚧 Project Status

> GenyDL is currently under active development.  
> Version **1.0.0** is the first milestone release, focused on the desktop UI, core download workflow, packaging, and runtime foundation.

## Highlights

- Modern QML-based desktop interface
- Multi-segment download engine foundation
- Resume, pause, retry, cancel, and remove actions
- Per-segment progress and download details window
- Queue and category-based download organization
- Adaptive segment controller foundation
- Per-task and global speed limit foundation
- Proxy, SSL, User-Agent, and network configuration foundation
- Runtime dashboard for CPU, memory, disk, network, and transfer status
- URL probe and integrated update client foundation
- Session persistence, import/export, and post-download action foundation
- Cross-platform packaging for macOS and Windows

## Planned Features

- Speed and network tester module
- Geny token and NFT ecosystem integration
- Application store for better maintenance and dependency updates
- Auto platform and file type detector
- Torrent and magnet backend support
- Advanced remote terminal repository updater
- YouTube and social media download support
- More advanced mirror failover and checksum verification workflows

## Shots
Soon...

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
