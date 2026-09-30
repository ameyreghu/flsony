import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/headphones_controller.dart';
import '../core/sound_profile.dart';
import 'theme.dart';
import 'widgets.dart';

/// Opt-in extra: saved sound setups, applied in one click.
class ProfilesSection extends StatelessWidget {
  const ProfilesSection({super.key, required this.controller, required this.settings});
  final HeadphonesController controller;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final profiles = settings.profiles;
    return Section(
      title: 'Profiles',
      trailing: LinkButton('Save current', onTap: () => _save(context, profiles)),
      child: Panel(
        child: profiles.isEmpty
            ? Text(
                'Save your current settings as a profile to switch back to them in one click.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: context.colors.textDim),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in profiles)
                        GestureDetector(
                          onSecondaryTap: () => _delete(context, profiles, p),
                          onLongPress: () => _delete(context, profiles, p),
                          child: Chip2(
                            label: p.name,
                            selected: _matches(p, controller),
                            onTap: () => _apply(context, p),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Right-click a profile to delete it.',
                    style: TextStyle(fontSize: 11.5, color: context.colors.textDim),
                  ),
                ],
              ),
      ),
    );
  }

  void _apply(BuildContext context, SoundProfile p) {
    controller.applyProfile(p);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.colors.surfaceHi,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'Applied “${p.name}”',
            style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  Future<void> _save(BuildContext context, List<SoundProfile> profiles) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: 'Profile ${profiles.length + 1}'),
    );
    if (name == null || name.trim().isEmpty) return;
    final profile = controller.captureProfile(name.trim());
    // Saving under an existing name replaces that profile.
    settings.profiles = [...profiles.where((p) => p.name != profile.name), profile];
  }

  Future<void> _delete(BuildContext context, List<SoundProfile> profiles, SoundProfile target) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete “${target.name}”?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: context.colors.danger, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (ok == true) settings.profiles = profiles.where((p) => p.name != target.name).toList();
  }
}

/// Whether the headphones are currently in the state the profile describes.
bool _matches(SoundProfile p, HeadphonesController c) {
  if (p.ncMode != null && p.ncMode != c.ncMode) return false;
  if (p.ncMode == NcMode.ambient && (p.ambientLevel != c.ambientLevel || p.focusOnVoice != c.ambientFocusOnVoice)) {
    return false;
  }
  if (p.speakToChat != null && p.speakToChat != c.speakToChat) return false;
  if (p.eqPresetId != null) {
    if (p.eqBands.isNotEmpty) return listEquals(p.eqBands, c.eqBands);
    if (p.eqPresetId != c.eqPresetId) return false;
  }
  return true;
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void submit() => Navigator.pop(context, _text.text);
    return AlertDialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Save profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: 24,
        onSubmitted: (_) => submit(),
        decoration: const InputDecoration(hintText: 'Name, e.g. Focus or Commute'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: submit,
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
