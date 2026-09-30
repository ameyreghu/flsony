# FlSony

Unofficial desktop app for **Sony WH-1000XM4** headphones on macOS: noise cancelling, EQ, Speak-to-Chat, battery and more. Built with Flutter; Windows support in progress.

Sony's *Sound Connect* app has no macOS or Windows version; FlSony fills that gap with a small, minimal interface. XM3 and XM5 are matched by name and may work, but are untested.

> Not affiliated with or endorsed by Sony. "Sony", "WH-1000XM4" and "Sound Connect" are trademarks of Sony Group Corporation. The protocol used here is community reverse-engineered and may change with firmware updates. Use at your own risk.

## Features

- Noise cancelling / Ambient sound / Off, with ambient level and *Focus on voice*
- Speak-to-Chat and touch-sensor toggles
- Equalizer: device presets, Custom 1/2 slots, and 5 bands + Clear Bass, locked behind an **Edit** button so you can't change it by accident
- Battery level and charging state
- Power off the headphones
- **Connection details** panel: transport, RFCOMM channel, protocol, session stats, advertised features and a live packet log

### Extras (opt-in)

Features Sony's app doesn't have. Each is off until you turn it on in **Settings → Extras**.

- **Menu bar / system tray icon**: battery next to the icon and a menu to switch noise mode or Speak-to-Chat. While it's on, closing the window keeps the app running.
- **Profiles**: save the current noise mode, ambient level, Focus on voice, Speak-to-Chat and EQ under a name and apply it in one click.
- **Pause media before power off**, so music doesn't jump to your laptop speakers.

## Status

| Platform | Status |
|---|---|
| macOS 12+ | Working. Uses IOBluetooth for the RFCOMM link. |
| Windows 10/11 | **Not working yet.** The Flutter UI and protocol code are shared, but the native Bluetooth bridge (`Windows.Devices.Bluetooth.Rfcomm`) is not written. Contributions welcome. |

Not implemented: multipoint / paired-device management, idle auto power-off, volume, and audio codec control. Audio itself is handled by your OS, not this app, and neither macOS nor Windows supports LDAC natively.

## How it works

Sony headphones expose a proprietary RFCOMM service ("Serial HPC", UUID `96CC203E-5068-46AD-B32D-E316F5E069BA`) on classic Bluetooth. The app is split in two:

- **Native bridge** (`macos/Runner/BluetoothPlugin.swift`): a thin byte pipe. It finds the paired headphones, opens the RFCOMM channel, forwards bytes both ways and reports connect / reachability events over a Flutter platform channel (`flsony/bt`).
- **Dart** (`lib/core`): everything else. Sony's framing (`sony_packet.dart`), the handshake, feature discovery and command/notify handling (`headphones_controller.dart`).

Keeping the protocol in Dart means a new platform only needs the small native bridge.

Frame layout: `0x3E  dataType  seq  len(BE32)  payload  checksum  0x3C`, where `0x3C/0x3D/0x3E` inside the body are escaped as `0x3D` followed by `byte & 0xEF`.

## Build and run

Requirements: Flutter 3.47+, plus Xcode on macOS or Visual Studio 2022 with the "Desktop development with C++" workload on Windows. Pair the headphones in system Bluetooth settings first.

```sh
flutter pub get
flutter run -d macos     # or: flutter run -d windows
flutter test
```

On first launch macOS asks for Bluetooth permission. Debug builds are ad-hoc signed, so macOS may ask again after each rebuild. Release builds are not signed or notarized.

The app icon is drawn by `tool/make_icon.swift`; run `tool/install_icons.sh` to regenerate the macOS and Windows icons from it.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The Dart ↔ native contract, and the plan for the Windows Bluetooth bridge, are in [docs/platform-bridge.md](docs/platform-bridge.md).

## Credits

This project stands on other people's reverse-engineering work:

- **[tanat/sony-connect-osx](https://github.com/tanat/sony-connect-osx)** by Tanat Kamalov and contributors. The native macOS menu-bar app this one is based on. The handshake sequence, opcode usage, touch-panel slot discovery and EQ/NCASM payload handling were ported from it to Dart.
- **[SonyHeadphonesClient](https://github.com/Plutoberth/SonyHeadphonesClient)** by Plutoberth and contributors. Source of the framing and NCASM payload structure.
- **[Gadgetbridge](https://codeberg.org/Freeyourgadget/Gadgetbridge)**. Source of the V1 opcode tables and capability negotiation logic.

Fonts are bundled under the SIL Open Font License 1.1: [Manrope](https://fonts.google.com/specimen/Manrope) and [Space Grotesk](https://fonts.google.com/specimen/Space+Grotesk) (licenses in `assets/fonts`).

## License

MIT, see [LICENSE](LICENSE), covering the code written for this repository. Third-party fonts keep their own licenses.
