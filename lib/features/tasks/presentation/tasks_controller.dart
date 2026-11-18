import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../analytics/data/activity_log.dart';
import '../data/task_repository.dart';

/// Ids completed during this session. Overdue tasks normally drop out of the
/// Today scope once done; this keeps them visible so the completion animation
/// isn't cut short.
final sessionDoneIdsProvider = StateProvider<Set<int>>((_) => const {});

class TasksController extends AsyncNotifier<List<Tasks>> {
  TaskRepository get _repo => ref.read(taskRepositoryProvider);
  OfflineCache get _cache => ref.read(offlineCacheProvider);
  List<Tasks> get _current => state.valueOrNull ?? const <Tasks>[];

  bool _syncing = false;

  /// Replays pending offline mutations against the backend when network is restored.
  Future<void> syncPending() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final actions = _cache.getPendingActions();
      if (actions.isEmpty) return;

      final remaining = <Map<String, dynamic>>[];

      for (final action in actions) {
        final type = action['type'] as String?;
        try {
          if (type == 'create_task') {
            final tempId = action['temp_id'] as int;
            final post = TasksPost.fromJson(Map<String, dynamic>.from(action['data'] as Map));
            final created = await _repo.create(post);
            if (created != null) {
              final current = state.valueOrNull ?? _cache.getTasks();
              final updated = current.map((t) => t.id == tempId ? created : t).toList();
              state = AsyncData(updated);
              await _cache.saveTasks(updated);
            }
          } else if (type == 'toggle_task' || type == 'edit_task') {
            final taskId = action['task_id'] as int;
            final post = TasksPost.fromJson(Map<String, dynamic>.from(action['data'] as Map));
            await _repo.update(taskId, post);
          } else if (type == 'delete_task') {
            final taskId = action['task_id'] as int;
            await _repo.delete(taskId);
          }
        } catch (_) {
          // Still offline or failed -> keep in queue
          remaining.add(action);
        }
      }

      await _cache.savePendingActions(remaining);
    } finally {
      _syncing = false;
    }
  }

  @override
  Future<List<Tasks>> build() async {
    // Rebuild (and refetch) when the signed-in user changes.
    final uid = ref.watch(currentUserProvider.select((u) => u?.id ?? u?.email));
    if (uid == null) return const <Tasks>[];

    // Load instantly from Hive offline cache if available (zero loading spinner!)
    final cached = _cache.getTasks();
    if (cached.isNotEmpty) {
      state = AsyncData(_sorted(cached));
    }

    try {
      await syncPending();
      final fresh = _sorted(await _repo.list());
      await _cache.saveTasks(fresh);
      return fresh;
    } catch (_) {
      if (cached.isNotEmpty) {
        return _sorted(state.valueOrNull ?? cached);
      }
      rethrow;
    }
  }

  /// Pull-to-refresh / retry. Keeps cached data if the refetch fails.
  Future<void> refresh() async {
    try {
      await syncPending();
      final fresh = _sorted(await _repo.list());
      state = AsyncData(fresh);
      await _cache.saveTasks(fresh);
    } catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> add(TasksPost body) async {
    // 1. Optimistically create local task with temporary negative ID so user sees it instantly
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final localTask = Tasks(
      id: tempId,
      title: body.title,
      description: body.description,
      priority: body.priority,
      isCompleted: body.isCompleted ?? false,
      dueDate: body.dueDate,
      createdAt: DateTime.now(),
      subtasks: const [],
    );

    final next = [localTask, ..._current];
    state = AsyncData(next);
    await _cache.saveTasks(next);

    // 2. Queue action to Hive immediately so it is permanently persisted
    await _cache.addPendingAction({
      'action_id': tempId.toString(),
      'type': 'create_task',
      'temp_id': tempId,
      'data': body.toJson(),
    });

    // 3. Attempt sync in the background without blocking the UI or keeping the add button spinning
    unawaited(_backgroundCreate(tempId, body));
  }

  Future<void> _backgroundCreate(int tempId, TasksPost body) async {
    try {
      final created = await _repo.create(body).timeout(const Duration(seconds: 4));
      if (created != null) {
        final current = state.valueOrNull ?? _cache.getTasks();
        final replaced = current.map((t) => t.id == tempId ? created : t).toList();
        state = AsyncData(replaced);
        await _cache.saveTasks(replaced);
        await _cache.removePendingAction(tempId.toString());
      }
    } catch (_) {
      // Offline or network timed out: remains safely queued in Hive to sync later
    }
  }

  /// Optimistic complete/uncomplete; works offline and queues sync.
  Future<void> toggle(Tasks t) async {
    final next = t.copyWith(isCompleted: !t.isCompleted);
    applyLocal(next);

    if (t.id < 0) {
      // Offline local task: update its pending payload if present
      final actions = _cache.getPendingActions();
      final idx = actions.indexWhere((a) => a['temp_id'] == t.id);
      if (idx >= 0) {
        final data = Map<String, dynamic>.from(actions[idx]['data'] as Map);
        data['is_completed'] = next.isCompleted;
        actions[idx]['data'] = data;
        await _cache.savePendingActions(actions);
      }
      return;
    }

    final actionId = 'toggle_${t.id}_${DateTime.now().millisecondsSinceEpoch}';
    await _cache.addPendingAction({
      'action_id': actionId,
      'type': 'toggle_task',
      'task_id': t.id,
      'data': TasksPost.fromTask(next).toJson(),
    });

    unawaited(() async {
      try {
        final saved = await _repo.update(t.id, TasksPost.fromTask(next)).timeout(const Duration(seconds: 4));
        if (saved != null) applyLocal(saved.copyWith(subtasks: t.subtasks));
        await _cache.removePendingAction(actionId);
      } catch (_) {}
    }());
  }

  /// Full edit from the editor sheet; works offline.
  Future<Tasks> edit(Tasks t, TasksPost body) async {
    final merged = (body.title.isEmpty ? t : _merge(t, body)).copyWith(subtasks: t.subtasks);
    applyLocal(merged);

    if (t.id < 0) {
      final actions = _cache.getPendingActions();
      final idx = actions.indexWhere((a) => a['temp_id'] == t.id);
      if (idx >= 0) {
        actions[idx]['data'] = body.toJson();
        await _cache.savePendingActions(actions);
      }
      return merged;
    }

    final actionId = 'edit_${t.id}_${DateTime.now().millisecondsSinceEpoch}';
    await _cache.addPendingAction({
      'action_id': actionId,
      'type': 'edit_task',
      'task_id': t.id,
      'data': body.toJson(),
    });

    unawaited(() async {
      try {
        final saved = await _repo.update(t.id, body).timeout(const Duration(seconds: 4));
        final finalTask = (saved ?? merged).copyWith(subtasks: t.subtasks);
        applyLocal(finalTask);
        await _cache.removePendingAction(actionId);
      } catch (_) {}
    }());

    return merged;
  }

  /// Optimistic delete; works offline.
  Future<void> remove(int id) async {
    final before = _current;
    final updated = before.where((t) => t.id != id).toList();
    state = AsyncData(updated);
    await _cache.saveTasks(updated);

    if (id < 0) {
      await _cache.removePendingAction(id.toString());
      return;
    }

    final actionId = 'delete_${id}_${DateTime.now().millisecondsSinceEpoch}';
    await _cache.addPendingAction({
      'action_id': actionId,
      'type': 'delete_task',
      'task_id': id,
    });

    unawaited(() async {
      try {
        await _repo.delete(id).timeout(const Duration(seconds: 4));
        await _cache.removePendingAction(actionId);
      } catch (_) {}
    }());
  }

  /// Replaces a task in place (no network). Used by the detail screen too.
  void applyLocal(Tasks next) {
    final list = _current;
    final i = list.indexWhere((t) => t.id == next.id);
    if (i < 0) return;
    if (!list[i].isCompleted && next.isCompleted) {
      ref.read(sessionDoneIdsProvider.notifier).update((s) => {...s, next.id});
      try {
        ref.read(activityLogProvider.notifier).logDone('t:${next.id}');
      } catch (_) {}
    } else if (list[i].isCompleted && !next.isCompleted) {
      ref.read(sessionDoneIdsProvider.notifier).update((s) => s.where((id) => id != next.id).toSet());
      try {
        ref.read(activityLogProvider.notifier).undo('t:${next.id}');
      } catch (_) {}
    }
    final copy = [...list]..[i] = next;
    state = AsyncData(copy);
    _cache.saveTasks(copy);
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
