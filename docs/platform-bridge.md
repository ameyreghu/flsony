# Platform bridge

FlSony keeps all of Sony's protocol in Dart (`lib/core`). Each platform only
has to provide a thin native **byte pipe** to the headphones' RFCOMM service,
plus a couple of OS integrations. This document is the contract between the
two sides, and the plan for the Windows implementation.

The macOS implementation is the reference: `macos/Runner/BluetoothPlugin.swift`
and `macos/Runner/SystemPlugin.swift`.

## Bluetooth: `flsony/bt`

### Methods (`MethodChannel('flsony/bt')`, standard codec)

All return `null` immediately; results arrive as events.

| Method | Argument | Behaviour |
|---|---|---|
| `startMonitoring` | none | Start reporting whether the headphones are present at the Bluetooth link level (`reachable` events). Emit the current state once straight away. |
| `connect` | none | Find the paired headphones and open an RFCOMM connection to Sony's service. Emit `connecting`, then `connected` or `failed`. No-op if already connected or connecting. |
| `disconnect` | none | Close the RFCOMM connection. Emit `disconnected` once closed. |
| `send` | `Uint8List` | Write the bytes as-is. Framing is done in Dart. Drop silently if not connected. |

**Finding the headphones:** a paired device whose name contains
`WH-1000XM4`, `WH-1000XM5` or `WH-1000XM3`.

**Sony's service:** RFCOMM service UUID `96CC203E-5068-46AD-B32D-E316F5E069BA`
("Serial HPC").

**Fail fast:** if the headphones are paired but not currently connected to the
computer, emit `failed` with a reason like "Headphones are off or out of
range" instead of letting the OS time out.

### Events (`EventChannel('flsony/bt/events')`)

Each event is a map with a `type`:

| `type` | Other keys | When |
|---|---|---|
| `status` | `state`: `connecting` \| `connected` \| `disconnected` \| `failed`; optional `name` (device name), `reason` (user-facing text, shown for `failed` and while `connecting`), `details` (map of string → string, only on `connected`) | Connection lifecycle |
| `data` | `bytes`: `Uint8List` | Bytes received from the headphones, as they arrive (no framing needed) |
| `reachable` | `value`: bool; optional `name` | The headphones' Bluetooth link to the computer came up or went down |

`details` is shown verbatim in the Connection details panel. macOS sends
`Transport`, `Address`, `RFCOMM channel`, `Service UUID` and `Stack`.

Dart handles retries: after `failed` or `disconnected` it calls `connect`
again every 5 s, and 1 s after a `reachable: true`.

## System: `flsony/system`

| Method | Returns | Behaviour |
|---|---|---|
| `pauseMedia` | bool | Pause whatever is playing, without ever starting playback (a play/pause toggle is **not** acceptable). Return whether anything was asked to pause. Dart gives up after 4 s. |
| `prepareMediaPause` | none | Ask for any permission `pauseMedia` needs, now rather than at power-off time. |

Both are optional: a `MissingPluginException` is handled in Dart.

## Rules that apply to every platform

- **Never block the platform thread.** On macOS, Dart runs on it, so a blocked
  call freezes the whole UI; see the Bluetooth permission fix in
  `BluetoothPlugin.swift`. Anything that can wait (permission prompts, I/O,
  async OS APIs) must complete asynchronously and post results back.
- **Channel calls and events only on the platform thread.** Marshal results
  from background threads back before calling the event sink.
- **User-facing `reason` strings** should say what to do next, e.g. where the
  Bluetooth setting lives on that OS.

## Windows plan

Nothing here has been built or tested yet.

### Where the code goes

- New `windows/runner/bluetooth_plugin.{h,cpp}` and `system_plugin.{h,cpp}`,
  added to `windows/runner/CMakeLists.txt`.
- Register both in `FlutterWindow::OnCreate` (`windows/runner/flutter_window.cpp`)
  after `RegisterPlugins`, using `flutter::MethodChannel<flutter::EncodableValue>`
  with `flutter::StandardMethodCodec::GetInstance()` and
  `flutter::EventChannel` with `StreamHandlerFunctions`.
- Link `WindowsApp.lib` for C++/WinRT (headers ship with the Windows SDK).
  C++/WinRT coroutines are easiest with the runner target on C++20
  (`target_compile_features(${BINARY_NAME} PRIVATE cxx_std_20)`); otherwise
  use `.Completed(...)` handlers.

### Threading traps

- `main.cpp` already initialises COM as single-threaded
  (`CoInitializeEx(..., COINIT_APARTMENTTHREADED)`). Don't call
  `winrt::init_apartment`, and never `.get()` a WinRT async operation on the
  UI thread (C++/WinRT asserts on single-threaded apartments, and it would
  block the UI anyway).
- WinRT completions and the socket read loop run on thread-pool threads. Queue
  their results (mutex-protected) and `PostMessage` a custom `WM_APP + n`
  message to the Flutter window; drain the queue and call the event sink in
  `FlutterWindow::MessageHandler`.

### Bluetooth (`Windows.Devices.Bluetooth`, `Windows.Networking.Sockets`)

1. Paired devices: `DeviceInformation::FindAllAsync(BluetoothDevice::GetDeviceSelectorFromPairingState(true))`,
   filtered by name.
2. `BluetoothDevice::FromIdAsync(id)`. If `ConnectionStatus()` is
   `Disconnected`, emit `failed` ("Headphones are off or out of range").
3. `device.GetRfcommServicesForIdAsync(RfcommServiceId::FromUuid(<uuid above>), BluetoothCacheMode::Uncached)`.
4. `StreamSocket::ConnectAsync(service.ConnectionHostName(), service.ConnectionServiceName(),
   SocketProtectionLevel::BluetoothEncryptionAllowNullAuthentication)`.
5. Read loop: `DataReader` with `InputStreamOptions::Partial`, `LoadAsync(1024)`,
   forward each chunk as a `data` event. A zero-byte read or exception means
   the connection closed: emit `disconnected`.
6. `send`: `DataWriter::WriteBytes` + `StoreAsync`, serialised so writes
   don't overlap.
7. Reachability: subscribe to `BluetoothDevice::ConnectionStatusChanged`.
8. `details` on `connected`: `Transport` ("Classic Bluetooth · RFCOMM (SPP)"),
   `Address`, `RFCOMM service` (the connection service name), `Service UUID`,
   `Stack` ("Windows.Devices.Bluetooth (Windows)").

### Pause media

`GlobalSystemMediaTransportControlsSessionManager::RequestAsync()`, then
`TryPauseAsync()` on every session whose playback status is `Playing`. That's
idempotent and, unlike the macOS version, also covers browsers.
`prepareMediaPause` can be a no-op.

### Already handled on the Dart side

- The tray icon uses `assets/icon/tray.ico`, and a click opens the window
  (right-click opens the menu).
- Settings already says "System tray icon" on Windows.

### Testing checklist

- Pair the headphones in Settings → Bluetooth & devices.
- Quit FlSony on any other computer the headphones are connected to while
  testing; two control connections at once hasn't been tried.
- Check: connect on launch, every control, battery, EQ edit, profiles,
  power off (with and without "Pause media"), headphones off then on again
  (reconnects), tray icon and menu, closing to tray, light/dark theme.
