import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_controller.dart';

/// A task completion recorded on this device. The API stores no completion
/// timestamp for personal tasks, so analytics keeps its own log.
class ActivityEvent {
  const ActivityEvent(this.at, this.key);
  final DateTime at;

  /// `t:<taskId>` for personal tasks, `g:<groupId>:<taskId>` for group tasks.
  final String key;

  Map<String, dynamic> toJson() => {'at': at.millisecondsSinceEpoch, 'k': key};
  factory ActivityEvent.fromJson(Map<String, dynamic> j) => ActivityEvent(
      DateTime.fromMillisecondsSinceEpoch(j['at'] as int), j['k'] as String);
}

class ActivityLog extends Notifier<List<ActivityEvent>> {
  static const _k = 'activity_log_v1';
  static const _max = 3000;

  @override
  List<ActivityEvent> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_k);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ActivityEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  void _save() => ref.read(sharedPrefsProvider).setString(
      _k, jsonEncode(state.map((e) => e.toJson()).toList()));

  /// Records a completion (idempotent per key).
  void logDone(String key) {
    if (state.any((e) => e.key == key)) return;
    final next = [...state, ActivityEvent(DateTime.now(), key)];
    state = next.length > _max ? next.sublist(next.length - _max) : next;
    _save();
  }

  /// Task was un-completed → forget its completion.
  void undo(String key) {
    if (!state.any((e) => e.key == key)) return;
    state = state.where((e) => e.key != key).toList();
    _save();
  }
}

final activityLogProvider =
    NotifierProvider<ActivityLog, List<ActivityEvent>>(ActivityLog.new);
