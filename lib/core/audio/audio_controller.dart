import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme_controller.dart';

/// Audio effects manager powering the "Audio Reactive FX" setting.
///
/// Plays low-latency UI chimes and pops on task completions, milestone
/// celebrations, and user actions.
class AudioFxService {
  AudioFxService(this._ref) {
    _player = AudioPlayer();
    _player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: const {
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
    ));
  }

  final Ref _ref;
  late final AudioPlayer _player;

  bool get _enabled => _ref.read(prefsProvider).audioFx;

  /// High-pitch pleasant completion chime.
  Future<void> playChime() async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/chime.wav'), volume: 0.9);
    } catch (_) {}
  }

  /// Subtle tactile click/pop for UI actions.
  Future<void> playPop() async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/pop.wav'), volume: 0.75);
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
  }
}

final audioFxProvider = Provider<AudioFxService>((ref) {
  final service = AudioFxService(ref);
  ref.onDispose(service.dispose);
  return service;
});
