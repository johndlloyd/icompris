# iCompris (macOS Edition) 🍎

**"J'ai compris" — for the modern Mac.**

### 💡 About the Project

**iCompris** is a community-driven fork of the legendary [GCompris](https://gcompris.net/) educational suite. While the original project provides a world-class learning experience for children globally, the macOS binaries have often lagged behind.

This fork aims to provide a **native, high-performance, and up-to-date experience** specifically for macOS (Intel & Apple Silicon), leveraging the latest Qt6 libraries and modern build workflows.

---

### 🎖️ Homage & Heritage

This project would not exist without the vision of **Bruno Coudoin**, who founded GCompris in 2000, and the tireless work of the **KDE Education team** (notably Timothée Giet and Johnny Jazeix).

The name **iCompris** is a nod to:

* **The Original Pun:** *"J'ai compris"* (French for "I have understood").
* **The Platform:** A tribute to the classic Apple "i" naming convention.
* **The Goal:** Making high-quality open-source education accessible on the hardware parents and schools already use.

---

### 🚀 Key Improvements in this Fork

* **Apple Silicon Native:** Optimized for M1/M2/M3/M4 chips.
* **Qt6 Migration:** Full support for the latest graphics rendering.
* **Streamlined DMG:** A simplified installer that adheres to modern macOS security and notarization standards.

---

### 📦 Status

* **Current target:** macOS arm64 (Apple Silicon)
* **Build output:** `dist/gcompris-qt-26.0-macos-arm64-internal.dmg`
* **Build script:** `tools/macos_build_dmg.sh`
* **Distribution mode:** Internal/ad-hoc signed DMG (not notarized for public distribution)
* **Known caveat:** Homebrew Qt layouts can be inconsistent for packaging; Qt online installer builds are preferred for repeatable release artifacts.

---

### 🛠️ Installation & Building

To build **iCompris** from source, you will need `CMake`, `Qt6`, and `Xcode` tools.

```bash
git clone git@github.com:johndlloyd/icompris.git
cd icompris
./tools/macos_build_dmg.sh
```

---

### ⚖️ License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**.

* **Copyleft:** Any changes made to this source code must be made public under the same license.
* **Trademarks:** GCompris is a trademark of its respective owners. This fork is an independent community project and is not officially endorsed by the KDE GCompris team.
