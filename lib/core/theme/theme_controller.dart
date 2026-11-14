import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_palette.dart';

class AppPrefsState {
  final AppThemeVariant variant;
  final bool hapticsEnabled;
  final bool audioFx;
  final bool autoStartBreaks;
  final int workMinutes; // 25 / 45 / 60
  final int breakMinutes; // 5 / 10 / 15

  const AppPrefsState({
    this.variant = AppThemeVariant.obsidianApplePrecision,
    this.hapticsEnabled = true,
    this.audioFx = true,
    this.autoStartBreaks = true,
    this.workMinutes = 25,
    this.breakMinutes = 5,
  });

  AppPrefsState copyWith({
    AppThemeVariant? variant,
    bool? hapticsEnabled,
    bool? audioFx,
    bool? autoStartBreaks,
    int? workMinutes,
    int? breakMinutes,
  }) =>
      AppPrefsState(
        variant: variant ?? this.variant,
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
class Haptics {
  Haptics(this._ref);
  final Ref _ref;
  bool get _on => _ref.read(prefsProvider).hapticsEnabled;

  void light() {
    if (_on) HapticFeedback.lightImpact();
  }

  void medium() {
    if (_on) HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (_on) HapticFeedback.heavyImpact();
  }

  void selection() {
    if (_on) HapticFeedback.selectionClick();
  }

  Future<void> success() async {
    if (!_on) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }
}

final hapticsProvider = Provider<Haptics>((ref) => Haptics(ref));
