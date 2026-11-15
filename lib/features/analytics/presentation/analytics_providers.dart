import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../focus/data/focus_history.dart';
import '../../groups/presentation/groups_providers.dart';
import '../../tasks/presentation/tasks_controller.dart';
import '../data/activity_log.dart';
import '../data/streaks.dart';

enum AnalyticsRange { week, month, year }

class Bucket {
  const Bucket(this.label, this.tasks, this.focusSeconds, this.start);
  final String label;
  final int tasks;
  final int focusSeconds;
  final DateTime start;
}

class FocusSlice {
  const FocusSlice(this.label, this.seconds);
  final String label;
  final int seconds;
}

class AnalyticsData {
  const AnalyticsData({
    required this.buckets,
    required this.tasksDone,
    required this.prevTasksDone,
    required this.focusSeconds,
    required this.goalSeconds,
    required this.streak,
    required this.velocity,
    required this.score,
    required this.slices,
    required this.heat,
    required this.totalTasks,
    required this.completedTotal,
  });
  final List<Bucket> buckets;
  final int tasksDone, prevTasksDone;
  final int focusSeconds, goalSeconds;
  final StreakInfo streak;
  final double velocity;
  final int score;
  final List<FocusSlice> slices;
  final Map<DateTime, int> heat; // last 84 days → activity count
  final int totalTasks, completedTotal;

  /// % change vs the previous period (null when there is no baseline).
  int? get deltaPercent => prevTasksDone == 0
      ? null
      : (((tasksDone - prevTasksDone) * 100) / prevTasksDone).round();
  bool get isEmpty => tasksDone == 0 && focusSeconds == 0 && completedTotal == 0;
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// Everything shown on the Analytics tab, computed live from:
///  • personal + group task completion (API state + local completion log),
///  • local focus session history.
final analyticsProvider = Provider.autoDispose
    .family<AnalyticsData, AnalyticsRange>((ref, range) {
  final tasks = ref.watch(tasksControllerProvider).valueOrNull ?? const <Tasks>[];
  final groups = ref.watch(groupsControllerProvider).valueOrNull ?? const <Group>[];
  final me = ref.watch(myUserIdProvider);
  final log = ref.watch(activityLogProvider);
  final sessions = ref.watch(focusHistoryProvider);

  final myGroupTasks = <GroupTaskResponse>[];
  for (final g in groups) {
    final l = ref.watch(groupTasksProvider(g.id)).valueOrNull;
    if (l == null) continue;
    myGroupTasks.addAll(me == null ? l : l.where((t) => t.assignedTo == me));
  }

  // completion timestamps (local log + group tasks the server says are done)
  final doneAt = <DateTime>[];
  final keys = <String>{};
  for (final e in log) {
    doneAt.add(e.at);
    keys.add(e.key);
  }
  for (final t in myGroupTasks) {
    if (t.isCompleted &&
        t.updatedAt != null &&
        !keys.contains('g:${t.groupId}:${t.id}')) {
      doneAt.add(t.updatedAt!);
    }
  }

  final now = DateTime.now();
  final today = _d(now);

  late DateTime start, end, prevStart;
  late int periodDays;
  late int goalHours;
  switch (range) {
    case AnalyticsRange.week:
      start = today.subtract(Duration(days: today.weekday - 1));
      end = start.add(const Duration(days: 7));
      prevStart = start.subtract(const Duration(days: 7));
      periodDays = 7;
      goalHours = 12;
    case AnalyticsRange.month:
      start = DateTime(today.year, today.month, 1);
      end = DateTime(today.year, today.month + 1, 1);
      prevStart = DateTime(today.year, today.month - 1, 1);
      periodDays = end.difference(start).inDays;
      goalHours = 48;
    case AnalyticsRange.year:
      start = DateTime(today.year, 1, 1);
      end = DateTime(today.year + 1, 1, 1);
      prevStart = DateTime(today.year - 1, 1, 1);
      periodDays = end.difference(start).inDays;
      goalHours = 600;
  }

  bool inR(DateTime x, DateTime a, DateTime b) => !x.isBefore(a) && x.isBefore(b);

  // buckets
  final n = switch (range) {
    AnalyticsRange.week => 7,
    AnalyticsRange.month => periodDays,
    AnalyticsRange.year => 12,
  };
  final taskCounts = List<int>.filled(n, 0);
  final focusSecs = List<int>.filled(n, 0);
  int idx(DateTime x) => switch (range) {
        AnalyticsRange.week || AnalyticsRange.month => _d(x).difference(start).inDays,
        AnalyticsRange.year => x.month - 1,
      };
  for (final x in doneAt) {
    if (inR(x, start, end)) taskCounts[idx(x)]++;
  }
  for (final s in sessions) {
    if (inR(s.start, start, end)) focusSecs[idx(s.start)] += s.focusedSeconds;
  }
  const wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const mo = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
  final buckets = [
    for (var i = 0; i < n; i++)
      Bucket(
        switch (range) {
          AnalyticsRange.week => wd[i],
          AnalyticsRange.month => '${i + 1}',
          AnalyticsRange.year => mo[i],
        },
        taskCounts[i],
        focusSecs[i],
        switch (range) {
          AnalyticsRange.week || AnalyticsRange.month => start.add(Duration(days: i)),
          AnalyticsRange.year => DateTime(start.year, i + 1, 1),
        },
      ),
  ];

  final tasksDone = taskCounts.fold(0, (a, b) => a + b);
  final prevDone = doneAt.where((x) => inR(x, prevStart, start)).length;
  final focus = focusSecs.fold(0, (a, b) => a + b);

  final elapsedDays = (today.difference(start).inDays + 1).clamp(1, periodDays);
  final velocity = tasksDone / elapsedDays;

  final total = tasks.length + myGroupTasks.length;
  final completed = tasks.where((t) => t.isCompleted).length +
      myGroupTasks.where((t) => t.isCompleted).length;
  final cr = total == 0 ? 0.0 : completed / total;
  final goalSoFar = goalHours * 3600 * elapsedDays / periodDays;
  final fp = goalSoFar == 0 ? 0.0 : (focus / goalSoFar).clamp(0.0, 1.0);
  final score = (100 * (0.5 * cr + 0.5 * fp)).round();

  // focus distribution by task
  final byTask = <String, int>{};
  for (final s in sessions) {
    if (inR(s.start, start, end)) {
      final k = s.taskTitle ?? 'Free focus';
      byTask[k] = (byTask[k] ?? 0) + s.focusedSeconds;
    }
  }
  final sorted = byTask.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final slices = <FocusSlice>[
    for (final e in sorted.take(3)) FocusSlice(e.key, e.value),
    if (sorted.length > 3)
      FocusSlice('Other', sorted.skip(3).fold(0, (a, e) => a + e.value)),
  ];

  // heatmap: last 12 weeks, ending this week
  final heat = <DateTime, int>{};
  final heatStart = today.subtract(Duration(days: today.weekday - 1 + 77));
  for (final x in doneAt) {
    final k = _d(x);
    if (!k.isBefore(heatStart)) heat[k] = (heat[k] ?? 0) + 1;
  }
  for (final s in sessions) {
    final k = _d(s.start);
    if (!k.isBefore(heatStart)) heat[k] = (heat[k] ?? 0) + 1;
  }

  return AnalyticsData(
    buckets: buckets,
    tasksDone: tasksDone,
    prevTasksDone: prevDone,
    focusSeconds: focus,
    goalSeconds: goalHours * 3600,
    streak: computeStreaks([...doneAt, ...sessions.map((s) => s.start)]),
    velocity: velocity,
    score: score,
    slices: slices,
    heat: heat,
    totalTasks: total,
    completedTotal: completed,
  );
});
