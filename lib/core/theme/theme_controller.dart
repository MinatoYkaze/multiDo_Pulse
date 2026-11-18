import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_palette.dart';

class AppPrefsState {
  final AppThemeVariant variant;
  final bool isDarkMode;
  final bool hapticsEnabled;
  final bool audioFx;
  final bool autoStartBreaks;
  final int workMinutes; // 25 / 45 / 60
  final int breakMinutes; // 5 / 10 / 15

  const AppPrefsState({
    this.variant = AppThemeVariant.obsidianApplePrecision,
    this.isDarkMode = true,
    this.hapticsEnabled = true,
    this.audioFx = true,
    this.autoStartBreaks = true,
    this.workMinutes = 25,
    this.breakMinutes = 5,
  });

  AppPrefsState copyWith({
    AppThemeVariant? variant,
    bool? isDarkMode,
    bool? hapticsEnabled,
    bool? audioFx,
    bool? autoStartBreaks,
    int? workMinutes,
    int? breakMinutes,
  }) =>
      AppPrefsState(
        variant: variant ?? this.variant,
        isDarkMode: isDarkMode ?? this.isDarkMode,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        audioFx: audioFx ?? this.audioFx,
        autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
        workMinutes: workMinutes ?? this.workMinutes,
        breakMinutes: breakMinutes ?? this.breakMinutes,
      );
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) =>
    throw UnimplementedError(
        'Override sharedPrefsProvider in ProviderScope (see main.dart).'));

class PrefsController extends Notifier<AppPrefsState> {
  static const _kTheme = 'pref_theme_variant';
  static const _kDarkMode = 'pref_dark_mode';
  static const _kHaptics = 'pref_haptics';
  static const _kAudio = 'pref_audio_fx';
  static const _kAuto = 'pref_auto_breaks';
  static const _kWork = 'pref_work_min';
  static const _kBreak = 'pref_break_min';

  SharedPreferences get _p => ref.read(sharedPrefsProvider);

  @override
  AppPrefsState build() {
    final name = _p.getString(_kTheme);
    return AppPrefsState(
      variant: AppThemeVariant.values.firstWhere((v) => v.name == name,
          orElse: () => AppThemeVariant.obsidianApplePrecision),
      isDarkMode: _p.getBool(_kDarkMode) ?? true,
      hapticsEnabled: _p.getBool(_kHaptics) ?? true,
      audioFx: _p.getBool(_kAudio) ?? true,
      autoStartBreaks: _p.getBool(_kAuto) ?? true,
      workMinutes: _p.getInt(_kWork) ?? 25,
      breakMinutes: _p.getInt(_kBreak) ?? 5,
    );
  }

  Future<void> setVariant(AppThemeVariant v) async {
    state = state.copyWith(variant: v);
    await _p.setString(_kTheme, v.name);
  }

  Future<void> toggleDarkMode() async {
    final next = !state.isDarkMode;
    state = state.copyWith(isDarkMode: next);
    await _p.setBool(_kDarkMode, next);
  }

  Future<void> setDarkMode(bool dark) async {
    state = state.copyWith(isDarkMode: dark);
    await _p.setBool(_kDarkMode, dark);
  }

  Future<void> setHaptics(bool on) async {
    state = state.copyWith(hapticsEnabled: on);
    await _p.setBool(_kHaptics, on);
  }

  Future<void> setAudioFx(bool on) async {
    state = state.copyWith(audioFx: on);
    await _p.setBool(_kAudio, on);
  }

  Future<void> setAutoStartBreaks(bool on) async {
    state = state.copyWith(autoStartBreaks: on);
    await _p.setBool(_kAuto, on);
  }

  Future<void> setWorkMinutes(int m) async {
    state = state.copyWith(workMinutes: m);
    await _p.setInt(_kWork, m);
  }

  Future<void> setBreakMinutes(int m) async {
    state = state.copyWith(breakMinutes: m);
    await _p.setInt(_kBreak, m);
  }
}

final prefsProvider =
    NotifierProvider<PrefsController, AppPrefsState>(PrefsController.new);

/// Central haptics gate: every feature calls this instead of HapticFeedback
/// directly so the Settings toggle is always respected.
///
/// On Android, it routes through a custom native MethodChannel using Android's
/// Vibrator API with durations tuned for rotary (ERM) and linear (LRA) motors
/// (e.g. Samsung Galaxy M/A-series, Pixel, OnePlus).
/// On other platforms (or as a fallback), it uses Flutter's built-in HapticFeedback.
class Haptics {
  Haptics(this._ref);
  final Ref _ref;
  static const _channel = MethodChannel('com.example.multido/haptics');

  bool get _on => _ref.read(prefsProvider).hapticsEnabled;

  void _trigger(String method, VoidCallback fallback) {
    if (!_on) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _channel.invokeMethod<bool>(method).catchError((_) => false).then((handled) {
        if (handled != true) fallback();
      });
    } else {
      fallback();
    }
  }

  void light() {
    _trigger('light', HapticFeedback.lightImpact);
  }

  void medium() {
    _trigger('medium', HapticFeedback.mediumImpact);
  }

  void heavy() {
    _trigger('heavy', () {
      HapticFeedback.heavyImpact();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        HapticFeedback.vibrate();
      }
    });
  }

  void selection() {
    _trigger('selection', HapticFeedback.selectionClick);
  }

  Future<void> success() async {
    if (!_on) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final handled = await _channel.invokeMethod<bool>('success');
        if (handled == true) return;
      } catch (_) {
        // Fall back below if channel call fails.
      }
    }
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }
}

final hapticsProvider = Provider<Haptics>((ref) => Haptics(ref));
