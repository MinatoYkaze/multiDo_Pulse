import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/storage/offline_cache.dart';
import '../data/task_repository.dart';
import 'tasks_controller.dart';

class TaskDetailState {
  const TaskDetailState({required this.task, required this.subtasks});
  final Tasks task;
  final List<SubtaskResponse> subtasks;

  int get doneCount => subtasks.where((s) => s.isCompleted).length;
  double get ratio => subtasks.isEmpty ? 0 : doneCount / subtasks.length;

  TaskDetailState copyWith({Tasks? task, List<SubtaskResponse>? subtasks}) =>
      TaskDetailState(
          task: task ?? this.task, subtasks: subtasks ?? this.subtasks);
}

/// One task + its checklist. Mutations are optimistic where safe and always
/// mirrored into [tasksControllerProvider] so the Today list stays in sync.
class TaskDetailController
    extends AutoDisposeFamilyAsyncNotifier<TaskDetailState, int> {
  TaskRepository get _repo => ref.read(taskRepositoryProvider);
  TasksController get _list => ref.read(tasksControllerProvider.notifier);

  @override
  Future<TaskDetailState> build(int arg) async {
    final cachedTask = ref
        .watch(tasksControllerProvider)
        .valueOrNull
        ?.firstWhereOrNull((t) => t.id == arg)
        ?? ref.read(offlineCacheProvider).getTasks().firstWhereOrNull((t) => t.id == arg);

    if (cachedTask != null) {
      state = AsyncData(TaskDetailState(task: cachedTask, subtasks: cachedTask.subtasks));
    }

    if (arg < 0) {
      // Offline local task that has not reached server yet
      return TaskDetailState(task: cachedTask!, subtasks: cachedTask.subtasks);
    }

    try {
      final r =
          await Future.wait<dynamic>([_repo.get(arg), _repo.subtasks(arg)]);
      final subs = r[1] as List<SubtaskResponse>;
      final task = (r[0] as Tasks).copyWith(subtasks: subs);
      _list.applyLocal(task);
      return TaskDetailState(task: task, subtasks: subs);
    } catch (_) {
      if (cachedTask != null) {
        return TaskDetailState(task: cachedTask, subtasks: cachedTask.subtasks);
      }
      rethrow;
    }
  }

  void _set(TaskDetailState s) => state = AsyncData(s);

  /// Replaces the checklist and mirrors it into the task (and the Today list).
  void _setSubs(TaskDetailState cur, List<SubtaskResponse> subs) {
    final task = cur.task.copyWith(subtasks: subs);
    _set(TaskDetailState(task: task, subtasks: subs));
    _list.applyLocal(task);
  }

  // ── the task itself ──────────────────────────────────────────

  Future<void> toggleTask() async {
    final s = state.valueOrNull;
    if (s == null) return;
    await _list.toggle(s.task);
    final curTask = ref
        .read(tasksControllerProvider)
        .valueOrNull
        ?.firstWhereOrNull((t) => t.id == arg);
    if (curTask != null) {
      _set(s.copyWith(task: curTask));
    }
  }

  /// Server-confirmed edit (title, notes, priority, deadline).
  Future<void> edit(TasksPost body) async {
    final s = state.valueOrNull;
    if (s == null) return;
    final saved = await _list.edit(s.task, body);
    _set((state.valueOrNull ?? s).copyWith(task: saved));
  }

  Future<void> setPriority(Priority p) {
    final t = state.requireValue.task;
    return edit(TasksPost(
      title: t.title,
      description: t.description,
      priority: p,
      dueDate: t.dueDate,
      isCompleted: t.isCompleted,
      clearDueDate: t.dueDate == null,
    ));
  }

  Future<void> setDue(DateTime? due) {
    final t = state.requireValue.task;
    return edit(TasksPost(
      title: t.title,
      description: t.description,
      priority: t.priority,
      dueDate: due,
      isCompleted: t.isCompleted,
      clearDueDate: due == null,
    ));
  }

  // ── subtasks ─────────────────────────────────────────────────

  Future<void> addSubtask(String title) async {
    final s = state.valueOrNull;
    if (s == null) return;
    final tempSubId = -DateTime.now().millisecondsSinceEpoch;
    final localSub = SubtaskResponse(id: tempSubId, taskId: arg, title: title, isCompleted: false);
    final cur = state.valueOrNull ?? s;
    final updatedSubs = [...cur.subtasks, localSub];
    _setSubs(cur, updatedSubs);

    if (arg < 0) {
      // Local offline task: subtask is kept in local state & Hive
      return;
    }

    try {
      final created = await _repo.addSubtask(arg, title);
      if (created != null) {
        final nowCur = state.valueOrNull ?? cur;
        _setSubs(nowCur, nowCur.subtasks.map((e) => e.id == tempSubId ? created : e).toList());
      }
    } catch (_) {
      // Offline: keep localSub in memory & Hive
    }
  }

  Future<void> toggleSubtask(SubtaskResponse st) async {
    final s = state.valueOrNull;
    if (s == null) return;
    final next = st.copyWith(isCompleted: !st.isCompleted);
    _setSubs(s, _swap(s.subtasks, next));
    if (st.id < 0 || arg < 0) return;
    try {
      await _repo.updateSubtask(
          st.id, SubtaskUpdate(title: st.title, isCompleted: next.isCompleted));
    } catch (_) {
      // Offline: keep toggled state in Hive!
    }
  }

  Future<void> deleteSubtask(SubtaskResponse st) async {
    final s = state.valueOrNull;
    if (s == null) return;
    // Synchronous removal: Dismissible requires the row to leave the tree.
    _setSubs(s, s.subtasks.where((e) => e.id != st.id).toList());
    if (st.id < 0 || arg < 0) return;
    try {
      await _repo.deleteSubtask(st.id);
    } catch (_) {
      // Offline: keep deleted in Hive!
    }
  }

  static List<SubtaskResponse> _swap(
          List<SubtaskResponse> l, SubtaskResponse next) =>
      [for (final e in l) e.id == next.id ? next : e];
}

final taskDetailProvider = AsyncNotifierProvider.autoDispose
    .family<TaskDetailController, TaskDetailState, int>(
        TaskDetailController.new);
