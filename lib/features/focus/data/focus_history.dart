import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_controller.dart';

class FocusSession {
  const FocusSession({
    required this.id,
    required this.start,
    required this.plannedSeconds,
    required this.focusedSeconds,
    required this.completed,
    this.taskId,
    this.taskTitle,
  });
  final int id;
  final DateTime start;
  final int plannedSeconds;
  final int focusedSeconds;
  final bool completed;
  final int? taskId;
  final String? taskTitle;

  Map<String, dynamic> toJson() => {
        'id': id,
        's': start.millisecondsSinceEpoch,
        'p': plannedSeconds,
        'f': focusedSeconds,
        'c': completed,
        'ti': taskId,
        'tt': taskTitle,
      };

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        id: j['id'] as int,
        start: DateTime.fromMillisecondsSinceEpoch(j['s'] as int),
        plannedSeconds: j['p'] as int,
        focusedSeconds: j['f'] as int,
        completed: j['c'] as bool,
        taskId: j['ti'] as int?,
        taskTitle: j['tt'] as String?,
      );
}

/// Local focus-session history (the backend has no focus endpoints).
class FocusHistory extends Notifier<List<FocusSession>> {
  static const _k = 'focus_sessions_v1';
  static const _max = 1500;

  @override
  List<FocusSession> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_k);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => FocusSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  void add(FocusSession s) {
    final next = [...state, s];
    state = next.length > _max ? next.sublist(next.length - _max) : next;
    ref.read(sharedPrefsProvider).setString(
        _k, jsonEncode(state.map((e) => e.toJson()).toList()));
  }
}

final focusHistoryProvider =
    NotifierProvider<FocusHistory, List<FocusSession>>(FocusHistory.new);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int focusSecondsOn(List<FocusSession> l, DateTime day) => l
    .where((s) => sameDay(s.start, day))
    .fold(0, (a, s) => a + s.focusedSeconds);
