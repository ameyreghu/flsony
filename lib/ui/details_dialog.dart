import 'dart:async';

import 'package:flutter/material.dart';

import '../core/headphones_controller.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showConnectionDetails(BuildContext context, HeadphonesController c) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Palette.bg,
      insetPadding: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Palette.hairline)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680), child: _Details(c: c)),
    ),
  );
}

class _Details extends StatefulWidget {
  const _Details({required this.c});
  final HeadphonesController c;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _uptime(DateTime? t) {
    if (t == null) return '—';
    final d = DateTime.now().difference(t);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.c,
      builder: (context, _) {
        final c = widget.c;
        final rows = <(String, String)>[
          ('Status', c.isReady ? 'Connected' : c.phase.name),
          ...c.linkDetails.entries.map((e) => (e.key, e.value)),
          ('Protocol', 'Sony MDR V1 · “Headphones Connect”'),
          ('Framing', '0x3E … 0x3C, escaped, checksum'),
          ('Session uptime', _uptime(c.connectedAt)),
          ('Packets sent / received', '${c.txPackets} / ${c.rxPackets}'),
          ('Audio codec (reported)', c.audioCodec ?? 'not reported'),
          ('Model (reported)', c.modelName ?? 'not reported'),
          ('Firmware (reported)', c.firmwareVersion ?? 'not reported'),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 6),
              child: Row(children: [
                const Text('Connection details', style: TextStyle(fontFamily: Fonts.display, fontSize: 19, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Palette.textDim)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                children: [
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(children: [for (final r in rows) _Row(r.$1, r.$2)]),
                  ),
                  const SizedBox(height: 18),
                  Section(
                    title: 'Features advertised',
                    child: Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: c.featureSlots.isEmpty
                          ? const _Row('General settings', 'none reported yet')
                          : Column(children: [
                              for (final f in c.featureSlots)
                                _Row('Slot 0x${f.slot.toRadixString(16).toUpperCase()}', '${f.name} · ${f.type}'),
                            ]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Section(
                    title: 'Packet log',
                    child: Panel(
                      padding: const EdgeInsets.all(12),
                      child: c.packetLog.isEmpty
                          ? const Text('No traffic yet.', style: TextStyle(color: Palette.textDim, fontSize: 12))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final l in c.packetLog.reversed.take(40))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                                    child: Text.rich(
                                      TextSpan(children: [
                                        TextSpan(text: l.tx ? 'TX  ' : 'RX  ', style: TextStyle(color: l.tx ? Palette.warn : Palette.accent, fontWeight: FontWeight.w800)),
                                        TextSpan(text: l.hex),
                                      ]),
                                      style: const TextStyle(fontFamily: 'Menlo', fontFamilyFallback: ['Consolas', 'monospace'], fontSize: 11, color: Palette.textDim),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12.5, color: Palette.textDim))),
          Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
      );
}
