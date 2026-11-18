import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../data/focus_history.dart';
import 'focus_task_provider.dart';

enum FocusPhase { work, rest }

class FocusMilestone {
  const FocusMilestone({
    required this.sessionNumber,
    required this.focusedSeconds,
    required this.xp,
    this.taskId,
    this.taskTitle,
  });
  final int sessionNumber;
  final int focusedSeconds;
  final int xp;
  final int? taskId;
  final String? taskTitle;
}

class FocusState {
  const FocusState({
    required this.phase,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.running,
    required this.sessionIndex,
    this.cycleLength = 4,
    this.sessionStart,
    this.milestone,
    this.breakDone = false,
  });

  factory FocusState.initial(int workMinutes) => FocusState(
        phase: FocusPhase.work,
        totalSeconds: workMinutes * 60,
        remainingSeconds: workMinutes * 60,
        running: false,
        sessionIndex: 1,
      );

  final FocusPhase phase;
  final int totalSeconds;
  final int remainingSeconds;
  final bool running;
  final int sessionIndex;
  final int cycleLength;
  final DateTime? sessionStart;
  final FocusMilestone? milestone;
  final bool breakDone;

  int get elapsedSeconds => totalSeconds - remainingSeconds;
  double get progress =>
      totalSeconds == 0 ? 0 : (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
  bool get pristine => remainingSeconds == totalSeconds && !running;

  FocusState copyWith({
    FocusPhase? phase,
    int? totalSeconds,
    int? remainingSeconds,
    bool? running,
    int? sessionIndex,
    DateTime? sessionStart,
    bool clearSessionStart = false,
    FocusMilestone? milestone,
    bool clearMilestone = false,
    bool? breakDone,
  }) =>
      FocusState(
        phase: phase ?? this.phase,
        totalSeconds: totalSeconds ?? this.totalSeconds,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        running: running ?? this.running,
        sessionIndex: sessionIndex ?? this.sessionIndex,
        cycleLength: cycleLength,
        sessionStart: clearSessionStart ? null : (sessionStart ?? this.sessionStart),
        milestone: clearMilestone ? null : (milestone ?? this.milestone),
        breakDone: breakDone ?? this.breakDone,
      );
}

/// Pomodoro engine. Lives for the whole app session so the timer keeps
/// running while you browse other tabs. Uses an absolute end time, so it
/// stays correct even if the OS throttles timers in the background.
class FocusController extends Notifier<FocusState> {
  Timer? _timer;
  DateTime? _endAt;
  bool _halfFired = false;

  @override
  FocusState build() {
    ref.onDispose(() => _timer?.cancel());
    // Changing the work interval in Settings re-arms an untouched timer.
    ref.listen<int>(prefsProvider.select((p) => p.workMinutes), (_, m) {
      final s = state;
      if (s.phase == FocusPhase.work && s.pristine && s.milestone == null) {
        state = s.copyWith(totalSeconds: m * 60, remainingSeconds: m * 60);
      }
    });
    return FocusState.initial(ref.read(prefsProvider).workMinutes);
  }

  // ── controls ──

  void toggle() => state.running ? pause() : start();

  void start() {
    final s = state;
    if (s.remainingSeconds <= 0) return;
    final now = DateTime.now();
    _endAt = now.add(Duration(seconds: s.remainingSeconds));
    state = s.copyWith(
      running: true,
      sessionStart: s.phase == FocusPhase.work ? (s.sessionStart ?? now) : s.sessionStart,
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    ref.read(hapticsProvider).medium();
  }

  void pause() {
    _timer?.cancel();
    _endAt = null;
    state = state.copyWith(running: false);
    ref.read(hapticsProvider).light();
  }

  /// ±minutes on the current block (design: −5m / +5m).
  void adjust(int minutes) {
    final s = state;
    final newTotal = (s.totalSeconds + minutes * 60).clamp(300, 7200);
    final delta = newTotal - s.totalSeconds;
    if (delta == 0) return;
    final rem = (s.remainingSeconds + delta).clamp(1, 7200);
    if (_endAt != null) _endAt = _endAt!.add(Duration(seconds: delta));
    state = s.copyWith(totalSeconds: newTotal, remainingSeconds: rem);
    ref.read(hapticsProvider).selection();
  }

  void reset() {
    _timer?.cancel();
    _endAt = null;
    _halfFired = false;
    final p = ref.read(prefsProvider);
    final isWork = state.phase == FocusPhase.work;
    final secs = (isWork ? p.workMinutes : p.breakMinutes) * 60;
    state = state.copyWith(
      totalSeconds: secs,
      remainingSeconds: secs,
      running: false,
      clearSessionStart: true,
      breakDone: false,
    );
    ref.read(hapticsProvider).medium();
  }

  /// Work → jump to the break (partial time is banked if ≥ 1 min);
  /// Rest → jump to the next sprint.
  void skip() {
    final s = state;
    if (s.phase == FocusPhase.work) {
      _bankPartial();
      _toRest(milestone: null);
      ref.read(hapticsProvider).medium();
    } else {
      nextSprint();
    }
  }

  void startBreak() {
    if (state.phase != FocusPhase.rest) return;
    start();
  }

  void nextSprint() {
    _timer?.cancel();
    _endAt = null;
    _halfFired = false;
    final s = state;
    final m = ref.read(prefsProvider).workMinutes;
    final next = s.sessionIndex >= s.cycleLength ? 1 : s.sessionIndex + 1;
    state = FocusState(
      phase: FocusPhase.work,
      totalSeconds: m * 60,
      remainingSeconds: m * 60,
      running: false,
      sessionIndex: next,
      cycleLength: s.cycleLength,
    );
    start();
  }

  void dismissMilestone() {
    if (state.milestone != null) state = state.copyWith(clearMilestone: true);
  }

  // ── internals ──

  void _tick() {
    final end = _endAt;
    if (end == null) return;
    final ms = end.difference(DateTime.now()).inMilliseconds;
    final rem = (ms / 1000).ceil().clamp(0, 1 << 30);
    if (rem != state.remainingSeconds) {
      state = state.copyWith(remainingSeconds: rem);
      _tickHaptics(rem);
    }
    if (ms <= 0) {
      state.phase == FocusPhase.work ? _completeWork() : _completeRest();
    }
  }

  void _tickHaptics(int rem) {
    if (rem <= 0) return;
    final h = ref.read(hapticsProvider);
    final s = state;
    if (rem <= 10) {
      h.selection(); // countdown ticks
      return;
    }
    if (s.phase == FocusPhase.work) {
      if (!_halfFired && s.elapsedSeconds >= s.totalSeconds ~/ 2) {
        _halfFired = true;
        h.medium(); // halfway milestone
        return;
      }
      if (rem % 60 == 0) h.light(); // minute tick
    }
  }

  void _bankPartial() {
    final s = state;
    if (s.elapsedSeconds < 60) return;
    final task = ref.read(focusTaskProvider);
    ref.read(focusHistoryProvider.notifier).add(FocusSession(
          id: DateTime.now().millisecondsSinceEpoch,
          start: s.sessionStart ?? DateTime.now().subtract(Duration(seconds: s.elapsedSeconds)),
          plannedSeconds: s.totalSeconds,
          focusedSeconds: s.elapsedSeconds,
          completed: false,
          taskId: task?.id,
          taskTitle: task?.title,
        ));
  }

  void _toRest({required FocusMilestone? milestone}) {
    _timer?.cancel();
    _endAt = null;
    _halfFired = false;
    final secs = ref.read(prefsProvider).breakMinutes * 60;
    state = FocusState(
      phase: FocusPhase.rest,
      totalSeconds: secs,
      remainingSeconds: secs,
      running: false,
      sessionIndex: state.sessionIndex,
      cycleLength: state.cycleLength,
      milestone: milestone,
    );
  }

  void _completeWork() {
    _timer?.cancel();
    _endAt = null;
    final s = state;
    final task = ref.read(focusTaskProvider);
    final focused = s.totalSeconds;
    ref.read(focusHistoryProvider.notifier).add(FocusSession(
          id: DateTime.now().millisecondsSinceEpoch,
          start: s.sessionStart ?? DateTime.now().subtract(Duration(seconds: focused)),
          plannedSeconds: s.totalSeconds,
          focusedSeconds: focused,
          completed: true,
          taskId: task?.id,
          taskTitle: task?.title,
        ));
    _toRest(
      milestone: FocusMilestone(
        sessionNumber: s.sessionIndex,
        focusedSeconds: focused,
        xp: (focused / 60 * 4).round(), // 25 min → 100 XP
        taskId: task?.id,
        taskTitle: task?.title,
      ),
    );
    _celebrate();
    if (ref.read(prefsProvider).autoStartBreaks) startBreak();
  }

  void _completeRest() {
    _timer?.cancel();
    _endAt = null;
    state = state.copyWith(running: false, remainingSeconds: 0, breakDone: true);
    ref.read(hapticsProvider).success();
  }

  /// `[20, 50, 40, 60, 20]`-style celebration from the milestone design.
  Future<void> _celebrate() async {
    ref.read(audioFxProvider).playChime();
    final h = ref.read(hapticsProvider);
    h.heavy();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    h.medium();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    h.light();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await h.success();
  }
}

final focusControllerProvider =
    NotifierProvider<FocusController, FocusState>(FocusController.new);
