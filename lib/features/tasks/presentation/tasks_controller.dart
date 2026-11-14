import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/task_repository.dart';

/// Ids completed during this session. Overdue tasks normally drop out of the
/// Today scope once done; this keeps them visible so the completion animation
/// isn't cut short.
final sessionDoneIdsProvider = StateProvider<Set<int>>((_) => const {});

class TasksController extends AsyncNotifier<List<Tasks>> {
  TaskRepository get _repo => ref.read(taskRepositoryProvider);
  List<Tasks> get _current => state.valueOrNull ?? const <Tasks>[];

  @override
  Future<List<Tasks>> build() async {
    // Rebuild (and refetch) when the signed-in user changes.
    final uid = ref.watch(currentUserProvider.select((u) => u?.id ?? u?.email));
    if (uid == null) return const <Tasks>[];
    return _sorted(await _repo.list());
  }

  /// Pull-to-refresh / retry. Keeps cached data if the refetch fails.
  Future<void> refresh() async {
    try {
      state = AsyncData(_sorted(await _repo.list()));
    } catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> add(TasksPost body) async {
    final created = await _repo.create(body);
    if (created == null) {
      await refresh(); // server returned no body → resync
      return;
    }
    state = AsyncData([created, ..._current]);
  }

  /// Optimistic complete/uncomplete; rolls back and rethrows on failure.
  Future<void> toggle(Tasks t) async {
    final next = t.copyWith(isCompleted: !t.isCompleted);
    applyLocal(next);
    try {
      final saved = await _repo.update(t.id, TasksPost.fromTask(next));
      if (saved != null) applyLocal(saved.copyWith(subtasks: t.subtasks));
    } catch (_) {
      applyLocal(t);
      rethrow;
    }
  }

  /// Full edit from the editor sheet (waits for the server).
  Future<Tasks> edit(Tasks t, TasksPost body) async {
    final saved = await _repo.update(t.id, body);
    final merged = (saved ?? _merge(t, body)).copyWith(subtasks: t.subtasks);
    applyLocal(merged);
    return merged;
  }

  /// Optimistic delete; restores the list and rethrows on failure.
  Future<void> remove(int id) async {
    final before = _current;
    state = AsyncData(before.where((t) => t.id != id).toList());
    try {
      await _repo.delete(id);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }

  /// Replaces a task in place (no network). Used by the detail screen too.
  void applyLocal(Tasks next) {
    final list = _current;
    final i = list.indexWhere((t) => t.id == next.id);
    if (i < 0) return;
    if (!list[i].isCompleted && next.isCompleted) {
      ref.read(sessionDoneIdsProvider.notifier).update((s) => {...s, next.id});
    }
    final copy = [...list]..[i] = next;
    state = AsyncData(copy);
  }

  static Tasks _merge(Tasks t, TasksPost b) => t.copyWith(
        title: b.title,
        description: b.description ?? t.description,
        priority: b.priority,
        isCompleted: b.isCompleted ?? t.isCompleted,
        dueDate: b.dueDate,
        clearDueDate: b.dueDate == null,
      );

  /// Pending first (by due date, then priority), completed last.
  static List<Tasks> _sorted(List<Tasks> l) {
    final c = [...l];
    c.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      final ad = a.dueDate, bd = b.dueDate;
      if (ad != null && bd != null) {
        final d = ad.compareTo(bd);
        if (d != 0) return d;
      } else if (ad != null) {
        return -1;
      } else if (bd != null) {
        return 1;
      }
      final p = b.priority.index.compareTo(a.priority.index);
      if (p != 0) return p;
      return b.id.compareTo(a.id);
    });
    return c;
  }
}

final tasksControllerProvider =
    AsyncNotifierProvider<TasksController, List<Tasks>>(TasksController.new);

// ───────────────────────── view state ─────────────────────────

enum TaskFilter { all, pending, done }

final taskFilterProvider = StateProvider<TaskFilter>((_) => TaskFilter.all);

/// false = "Today" scope, true = every task.
final showAllTasksProvider = StateProvider<bool>((_) => false);

/// Spring checkbox / particle burst / staggered entrance (today_tasks_2) vs
/// the plain static look (today_tasks_1).
class RichMotionController extends Notifier<bool> {
  static const _k = 'pref_rich_motion';
  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(_k) ?? true;

  Future<void> toggle() async {
    state = !state;
    await ref.read(sharedPrefsProvider).setBool(_k, state);
  }
}

final richMotionProvider =
    NotifierProvider<RichMotionController, bool>(RichMotionController.new);

/// Tasks in the current scope: Today = undated + due today + overdue-pending.
final scopedTasksProvider = Provider<List<Tasks>>((ref) {
  final all = ref.watch(tasksControllerProvider).valueOrNull ?? const <Tasks>[];
  if (ref.watch(showAllTasksProvider)) return all;
  final keep = ref.watch(sessionDoneIdsProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));
  return all.where((t) {
    final d = t.dueDate;
    if (d == null) return true;
    if (!d.isBefore(start) && d.isBefore(end)) return true;
    if (d.isBefore(start)) return !t.isCompleted || keep.contains(t.id);
    return false;
  }).toList();
});

final visibleTasksProvider = Provider<List<Tasks>>((ref) {
  final scoped = ref.watch(scopedTasksProvider);
  switch (ref.watch(taskFilterProvider)) {
    case TaskFilter.all:
      return scoped;
    case TaskFilter.pending:
      return scoped.where((t) => !t.isCompleted).toList();
    case TaskFilter.done:
      return scoped.where((t) => t.isCompleted).toList();
  }
});

class TaskStats {
  const TaskStats(this.done, this.total);
  final int done;
  final int total;
  double get ratio => total == 0 ? 0 : done / total;
}

final taskStatsProvider = Provider<TaskStats>((ref) {
  final s = ref.watch(scopedTasksProvider);
  return TaskStats(s.where((t) => t.isCompleted).length, s.length);
});
