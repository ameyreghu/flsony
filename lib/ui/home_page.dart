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
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    Platform.isMacOS ? 34 : 18,
                    20,
                    24,
                  ).add(EdgeInsets.symmetric(horizontal: _sideInset(context))),
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
                                    Divider(height: 1, color: context.colors.hairline),
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
                if (Platform.isMacOS) const _TitleStrip(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// With the title bar hidden, content would scroll under the traffic lights.
/// This strip fades it out and lets the window be dragged from the top edge.
class _TitleStrip extends StatelessWidget {
  const _TitleStrip();

  @override
  Widget build(BuildContext context) {
    final bg = context.colors.bg;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 30,
      child: DragToMoveArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bg, bg, bg.withValues(alpha: 0)],
              stops: const [0, 0.7, 1],
            ),
          ),
        ),
      ),
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
      Phase.ready => ('Connected', context.colors.accentInk),
      Phase.connecting => ('Connecting…', context.colors.warn),
      Phase.idle => ('Standby', context.colors.warn),
      Phase.unavailable => ('Not connected', context.colors.textDim),
    };
    return Row(
      children: [
        // Only the identity block drags the window: DragToMoveArea's
        // double-tap recogniser would otherwise delay taps on the buttons.
        Expanded(
          child: DragToMoveArea(
            child: Row(
              children: [
                // The mark is tinted with the accent so it reads on light and dark.
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(context.colors.text, context.colors.accentInk, 0.35)!,
                      context.colors.accentInk,
                    ],
                  ).createShader(rect),
                  child: Image.asset(
                    'assets/icon/mark.png',
                    width: 44,
                    height: 44,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
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
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textDim,
                            ),
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
          icon: Icon(Icons.info_outline_rounded, size: 20, color: context.colors.textDim),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => showSettings(context, settings),
          icon: Icon(Icons.tune_rounded, size: 20, color: context.colors.textDim),
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.colors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            charging ? Icons.bolt_rounded : Icons.battery_std_rounded,
            size: 16,
            color: low ? context.colors.danger : context.colors.accentInk,
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
      Phase.connecting => (c.connectingDetail ?? 'Talking to your headphones…', true),
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
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.accentInk),
              )
            else
              Icon(Icons.bluetooth_disabled_rounded, size: 18, color: context.colors.textDim),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: context.colors.textDim)),
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
                              style: TextStyle(
                                fontFamily: Fonts.display,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: context.colors.accentInk,
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
            if (c.eqPresets.isEmpty)
              Text(
                'Presets and bands appear once the headphones are connected.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: context.colors.textDim),
              ),
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
                    ? Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'Changes are saved to the selected Custom slot as you release a slider.',
                          style: TextStyle(fontSize: 12, color: context.colors.textDim),
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
            backgroundColor: context.colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Power off headphones?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            content: Text(
              'They will switch off and Bluetooth will disconnect.',
              style: TextStyle(color: context.colors.textDim),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Power off',
                  style: TextStyle(color: context.colors.danger, fontWeight: FontWeight.w800),
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
        foregroundColor: context.colors.danger,
        side: BorderSide(color: context.colors.danger.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    );
  }
}

/// Keeps the content at a comfortable column width when the window is widened.
double _sideInset(BuildContext context) {
  const maxContent = 520.0;
  final width = MediaQuery.sizeOf(context).width;
  return width > maxContent + 40 ? (width - maxContent - 40) / 2 : 0;
}
