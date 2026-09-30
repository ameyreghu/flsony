import 'headphones_controller.dart';

/// A saved combination of sound settings, applied in one click.
/// Fields are null when the headphones hadn't reported them at save time.
class SoundProfile {
  const SoundProfile({
    required this.name,
    this.ncMode,
    this.ambientLevel = HeadphonesController.maxAmbientLevel,
    this.focusOnVoice = false,
    this.speakToChat,
    this.eqPresetId,
    this.eqBands = const [],
  });

  final String name;
  final NcMode? ncMode;
  final int ambientLevel;
  final bool focusOnVoice;
  final bool? speakToChat;
  final int? eqPresetId;

  /// Only kept for the unsaved "Custom" curve; saved slots and built-in
  /// presets are restored by id.
  final List<int> eqBands;

  Map<String, Object?> toJson() => {
    'name': name,
    'ncMode': ncMode?.name,
    'ambientLevel': ambientLevel,
    'focusOnVoice': focusOnVoice,
    'speakToChat': speakToChat,
    'eqPresetId': eqPresetId,
    'eqBands': eqBands,
  };

  factory SoundProfile.fromJson(Map<String, Object?> j) => SoundProfile(
    name: j['name'] as String,
    ncMode: j['ncMode'] == null ? null : NcMode.values.byName(j['ncMode'] as String),
    ambientLevel: (j['ambientLevel'] as int?) ?? HeadphonesController.maxAmbientLevel,
    focusOnVoice: (j['focusOnVoice'] as bool?) ?? false,
    speakToChat: j['speakToChat'] as bool?,
    eqPresetId: j['eqPresetId'] as int?,
    eqBands: ((j['eqBands'] as List?) ?? const []).cast<int>(),
  );
}
