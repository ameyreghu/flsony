import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_settings.dart';
import '../core/headphones_controller.dart';
import 'details_dialog.dart';
import 'equalizer.dart';
import 'profiles.dart';
import 'settings_dialog.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller, required this.settings});
  final HeadphonesController controller;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, settings]),
      builder: (context, _) {
        final c = controller;
        final ready = c.isReady;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, Platform.isMacOS ? 34 : 18, 20, 24),
              children: [
                _Header(c: c, settings: settings),
                const SizedBox(height: 22),
                if (!ready) _StatusBanner(c: c),
                AnimatedOpacity(
                  opacity: ready ? 1 : 0.4,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !ready,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (settings.profilesEnabled) ...[
                          ProfilesSection(controller: c, settings: settings),
                          const SizedBox(height: 22),
                        ],
                        Section(
                          title: 'Sound control',
                          child: _NoiseControl(c: c),
                        ),
                        const SizedBox(height: 22),
                        Section(
                          title: 'Features',
                          child: Panel(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Column(
                              children: [
                                ToggleRow(
                                  icon: Icons.record_voice_over_rounded,
                                  title: 'Speak-to-Chat',
                                  subtitle: 'Pauses music when you start talking',
                                  value: c.speakToChat,
                                  onChanged: c.toggleSpeakToChat,
                                ),
                                const Divider(height: 1, color: Palette.hairline),
                                ToggleRow(
                                  icon: Icons.touch_app_rounded,
                                  title: 'Touch sensor',
                                  subtitle: 'Swipe and tap on the right earcup',
                                  value: c.touchSensor,
                                  onChanged: c.toggleTouchSensor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _Equalizer(c: c),
                        const SizedBox(height: 26),
                        _PowerOff(c: c),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.c, required this.settings});
  final HeadphonesController c;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (c.phase) {
      Phase.ready => ('Connected', Palette.accent),
      Phase.connecting => ('Connecting…', Palette.warn),
      Phase.idle => ('Standby', Palette.warn),
      Phase.unavailable => ('Not connected', Palette.textDim),
    };
    return Row(
      children: [
        // Only the identity block drags the window: DragToMoveArea's
        // double-tap recogniser would otherwise delay taps on the buttons.
        Expanded(
          child: DragToMoveArea(
            child: Row(
              children: [
                Image.asset('assets/icon/mark.png', width: 44, height: 44, filterQuality: FilterQuality.medium),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: Fonts.display,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Palette.textDim),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (c.battery != null) _Battery(level: c.battery!, charging: c.charging),
        IconButton(
          tooltip: 'Connection details',
          onPressed: () => showConnectionDetails(context, c),
          icon: const Icon(Icons.info_outline_rounded, size: 20, color: Palette.textDim),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => showSettings(context, settings),
          icon: const Icon(Icons.tune_rounded, size: 20, color: Palette.textDim),
        ),
      ],
    );
  }
}

class _Battery extends StatelessWidget {
  const _Battery({required this.level, required this.charging});
  final int level;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final low = level <= 20 && !charging;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Palette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            charging ? Icons.bolt_rounded : Icons.battery_std_rounded,
            size: 16,
            color: low ? Palette.danger : Palette.accent,
          ),
          const SizedBox(width: 4),
          Text(
            '$level%',
            style: const TextStyle(fontFamily: Fonts.display, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.c});
  final HeadphonesController c;

  @override
  Widget build(BuildContext context) {
    final (text, busy) = switch (c.phase) {
      Phase.connecting => ('Talking to your headphones…', true),
      Phase.idle => ('Headphones found. Opening control channel…', true),
      _ => (
        c.failureReason ?? 'Turn on your headphones and make sure they are paired in system Bluetooth settings.',
        false,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Panel(
        child: Row(
          children: [
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Palette.accent),
              )
            else
              const Icon(Icons.bluetooth_disabled_rounded, size: 18, color: Palette.textDim),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: Palette.textDim)),
            ),
            if (!busy)
              TextButton(
                onPressed: c.reconnect,
                child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoiseControl extends StatefulWidget {
  const _NoiseControl({required this.c});
  final HeadphonesController c;

  @override
  State<_NoiseControl> createState() => _NoiseControlState();
}

class _NoiseControlState extends State<_NoiseControl> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final ambient = c.ncMode == NcMode.ambient;
    final level = _drag ?? c.ambientLevel.toDouble();
    return Panel(
      child: Column(
        children: [
          Segmented<NcMode>(
            enabled: c.isReady,
            value: c.ncMode,
            onChanged: c.setNcMode,
            options: const [
              SegmentOption(NcMode.noiseCancelling, 'Noise cancelling', Icons.noise_aware_rounded),
              SegmentOption(NcMode.ambient, 'Ambient', Icons.hearing_rounded),
              SegmentOption(NcMode.off, 'Off', Icons.noise_control_off_rounded),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !ambient
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Ambient level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text(
                              '${level.round()}',
                              style: const TextStyle(
                                fontFamily: Fonts.display,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Palette.accent,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          min: 0,
                          max: HeadphonesController.maxAmbientLevel.toDouble(),
                          divisions: HeadphonesController.maxAmbientLevel,
                          value: level,
                          onChanged: (v) => setState(() => _drag = v),
                          onChangeEnd: (v) {
                            setState(() => _drag = null);
                            c.setAmbientLevel(v.round());
                          },
                        ),
                        ToggleRow(
                          icon: Icons.graphic_eq_rounded,
                          title: 'Focus on voice',
                          subtitle: 'Let speech through, soften the rest',
                          value: c.ambientFocusOnVoice,
                          onChanged: () => c.setAmbientFocusOnVoice(!c.ambientFocusOnVoice),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Equalizer extends StatefulWidget {
  const _Equalizer({required this.c});
  final HeadphonesController c;

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final hasBands = c.eqBands.isNotEmpty;
    return Section(
      title: 'Equalizer',
      trailing: !hasBands
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_editing) LinkButton('Reset', onTap: () => c.setEqBands(List.filled(c.eqBands.length, 10))),
                const SizedBox(width: 14),
                LinkButton(_editing ? 'Done' : 'Edit', onTap: () => setState(() => _editing = !_editing)),
              ],
            ),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in c.eqPresets)
                  Chip2(label: p.name, selected: p.id == c.eqPresetId, onTap: () => c.setEqPreset(p.id)),
              ],
            ),
            if (hasBands) ...[
              const SizedBox(height: 18),
              Opacity(
                opacity: _editing ? 1 : 0.55,
                child: EqualizerBands(bands: c.eqBands, enabled: c.isReady && _editing, onCommit: c.setEqBands),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                child: _editing
                    ? const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'Changes are saved to the selected Custom slot as you release a slider.',
                          style: TextStyle(fontSize: 12, color: Palette.textDim),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PowerOff extends StatelessWidget {
  const _PowerOff({required this.c});
  final HeadphonesController c;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Palette.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Power off headphones?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            content: const Text(
              'They will switch off and Bluetooth will disconnect.',
              style: TextStyle(color: Palette.textDim),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Power off',
                  style: TextStyle(color: Palette.danger, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
        if (ok == true) c.powerOff();
      },
      icon: const Icon(Icons.power_settings_new_rounded, size: 18),
      label: const Text('Power off headphones'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.danger,
        side: BorderSide(color: Palette.danger.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
  }
}
