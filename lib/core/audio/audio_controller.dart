import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme_controller.dart';

/// Audio effects manager powering the "Audio Reactive FX" setting.
///
/// Plays low-latency UI chimes and pops on task completions, milestone
/// celebrations, and user actions.
class AudioFxService {
  AudioFxService(this._ref) {
    try {
      final p = AudioPlayer();
      _player = p;
      p.setAudioContext(AudioContext(
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
      )).catchError((_) {});
    } catch (_) {
      _player = null;
    }
  }

  AudioFxService._noop(this._ref) : _player = null;

  final Ref _ref;
  AudioPlayer? _player;

  bool get _enabled {
    try {
      return _ref.read(prefsProvider).audioFx;
    } catch (_) {
      return false;
    }
  }

  /// High-pitch pleasant completion chime.
  Future<void> playChime() async {
    try {
      if (!_enabled) return;
      await _player?.stop();
      await _player?.play(AssetSource('sounds/chime.wav'), volume: 0.9);
    } catch (_) {}
  }

  /// Subtle tactile click/pop for UI actions.
  Future<void> playPop() async {
    try {
      if (!_enabled) return;
      await _player?.stop();
      await _player?.play(AssetSource('sounds/pop.wav'), volume: 0.75);
    } catch (_) {}
  }

  void dispose() {
    try {
      _player?.dispose();
    } catch (_) {}
  }
}

final audioFxProvider = Provider<AudioFxService>((ref) {
  try {
    final service = AudioFxService(ref);
    ref.onDispose(service.dispose);
    return service;
  } catch (_) {
    return AudioFxService._noop(ref);
  }
});
