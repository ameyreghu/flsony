import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_settings.dart';
import '../core/headphones_controller.dart';

/// Menu-bar (macOS) / system-tray (Windows) icon with quick controls.
/// While it's enabled, closing the window hides it instead of quitting.
class TrayMenu with TrayListener, WindowListener {
  TrayMenu(this.headphones, this.settings);

  final HeadphonesController headphones;
  final AppSettings settings;
  bool _visible = false;
  String? _lastSignature;
  Timer? _debounce;

  Future<void> init() async {
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    settings.addListener(_syncVisibility);
    // The controller notifies on every packet; coalesce menu rebuilds.
    headphones.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 120), _refresh);
    });
    await _syncVisibility();
  }

  Future<void> _syncVisibility() async {
    if (settings.menuBarIcon == _visible) return;
    _visible = settings.menuBarIcon;
    if (_visible) {
      trayManager.addListener(this);
      await trayManager.setIcon(
        Platform.isWindows ? 'assets/icon/tray.ico' : 'assets/icon/tray_template.png',
        isTemplate: true,
      );
      _lastSignature = null;
      await _refresh();
    } else {
      trayManager.removeListener(this);
      await trayManager.destroy();
    }
  }

  Future<void> _refresh() async {
    if (!_visible) return;
    final h = headphones;
    final signature = [h.phase, h.deviceName, h.battery, h.charging, h.ncMode, h.speakToChat].join('|');
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    final battery = h.isReady && h.battery != null ? '${h.battery}%${h.charging ? ' ⚡' : ''}' : '';
    final status = switch (h.phase) {
      Phase.ready => battery.isEmpty ? 'Connected' : 'Connected · $battery',
      Phase.connecting || Phase.idle => 'Connecting…',
      Phase.unavailable => 'Not connected',
    };
    if (Platform.isMacOS) await trayManager.setTitle(battery.isEmpty ? '' : ' $battery');
    await trayManager.setToolTip('${h.deviceName} · $status');

    final ready = h.isReady;
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(label: '${h.deviceName} — $status', disabled: true),
          MenuItem.separator(),
          _mode('nc', 'Noise cancelling', NcMode.noiseCancelling, ready),
          _mode('ambient', 'Ambient sound', NcMode.ambient, ready),
          _mode('off', 'Off', NcMode.off, ready),
          MenuItem.separator(),
          MenuItem.checkbox(
            key: 'stc',
            label: 'Speak-to-Chat',
            checked: h.speakToChat ?? false,
            disabled: !ready || h.speakToChat == null,
          ),
          MenuItem.separator(),
          MenuItem(key: 'open', label: 'Open FlSony'),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );
  }

  MenuItem _mode(String key, String label, NcMode mode, bool ready) =>
      MenuItem.checkbox(key: key, label: label, checked: headphones.ncMode == mode, disabled: !ready);

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  // --- TrayListener -------------------------------------------------------
  @override
  void onTrayIconMouseDown() {
    // macOS convention: click opens the menu. Windows: click opens the app.
    Platform.isMacOS ? trayManager.popUpContextMenu() : _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'nc':
        headphones.setNcMode(NcMode.noiseCancelling);
      case 'ambient':
        headphones.setNcMode(NcMode.ambient);
      case 'off':
        headphones.setNcMode(NcMode.off);
      case 'stc':
        headphones.toggleSpeakToChat();
      case 'open':
        _showWindow();
      case 'quit':
        windowManager.destroy();
    }
  }

  // --- WindowListener -----------------------------------------------------
  @override
  void onWindowClose() {
    settings.menuBarIcon ? windowManager.hide() : windowManager.destroy();
  }
}
