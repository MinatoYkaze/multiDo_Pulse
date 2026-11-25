import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/group_repository.dart';
import '../data/invitation_repository.dart';

// ---------------------------------------------------------------------------
// Groups List Controller
// ---------------------------------------------------------------------------

class GroupsController extends AsyncNotifier<List<Group>> {
  GroupRepository get _repo => ref.read(groupRepositoryProvider);
  List<Group> get _current => state.valueOrNull ?? const <Group>[];

  @override
  Future<List<Group>> build() async {
    final uid =
        ref.watch(currentUserProvider.select((u) => u?.id ?? u?.email));
    if (uid == null) return const <Group>[];
    return await _repo.list();
  }

  Future<void> refresh() async {
    try {
      final list = await _repo.list();
      state = AsyncData(list);
    } catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<Group> createGroup(String name, [String? description]) async {
    final created = await _repo.create(GroupPost(
      name: name,
      description: description,
    ));
    state = AsyncData([created, ..._current]);
    return created;
  }

  Future<Group> updateGroup(int id,
      {String? name, String? description}) async {
    final updated = await _repo.update(
      id,
      UpdateGroup(name: name, description: description),
    );
    final list = _current;
    final idx = list.indexWhere((g) => g.id == id);
    if (idx >= 0) {
      final copy = [...list]..[idx] = updated;
      state = AsyncData(copy);
    }
    return updated;
  }

  Future<void> deleteGroup(int id) async {
    final before = _current;
    state = AsyncData(before.where((g) => g.id != id).toList());
    try {
      await _repo.delete(id);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> leaveGroup(int id) async {
    final before = _current;
    state = AsyncData(before.where((g) => g.id != id).toList());
    try {
      await _repo.leave(id);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}

final groupsControllerProvider =
    AsyncNotifierProvider<GroupsController, List<Group>>(
  GroupsController.new,
);

// ---------------------------------------------------------------------------
// Group Details Provider
// ---------------------------------------------------------------------------

final groupDetailProvider = FutureProvider.family<Group, int>((ref, id) async {
  final repo = ref.watch(groupRepositoryProvider);
  return await repo.get(id);
});

// ---------------------------------------------------------------------------
// Group Members Controller
// ---------------------------------------------------------------------------

class GroupMembersController
    extends FamilyAsyncNotifier<List<GroupMemberResponse>, int> {
  GroupRepository get _repo => ref.read(groupRepositoryProvider);
  List<GroupMemberResponse> get _current =>
      state.valueOrNull ?? const <GroupMemberResponse>[];

  @override
  Future<List<GroupMemberResponse>> build(int arg) async {
    return await _repo.members(arg);
  }

  Future<void> refresh() async {
    try {
      final members = await _repo.members(arg);
      state = AsyncData(members);
    } catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<InGroupInvitationResponse> invite(String email) async {
    final res = await _repo.invite(arg, email);
    await refresh();
    return res;
  }

  Future<void> removeMember(int userId) async {
    final before = _current;
    state = AsyncData(before.where((m) => m.userId != userId).toList());
    try {
      await _repo.removeMember(arg, userId);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}

final groupMembersControllerProvider = AsyncNotifierProvider.family<
    GroupMembersController, List<GroupMemberResponse>, int>(
  GroupMembersController.new,
);

// ---------------------------------------------------------------------------
// Group Tasks Controller
// ---------------------------------------------------------------------------

class GroupTasksController
    extends FamilyAsyncNotifier<List<GroupTaskResponse>, int> {
  GroupRepository get _repo => ref.read(groupRepositoryProvider);
  List<GroupTaskResponse> get _current =>
      state.valueOrNull ?? const <GroupTaskResponse>[];

  @override
  Future<List<GroupTaskResponse>> build(int arg) async {
    final tasks = await _repo.tasks(arg);
    return _sortTasks(tasks);
  }

  Future<void> refresh() async {
    try {
      final tasks = await _repo.tasks(arg);
      state = AsyncData(_sortTasks(tasks));
    } catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<GroupTaskResponse> createTask(GroupTasksCreate body) async {
    final created = await _repo.createTask(arg, body);
    state = AsyncData(_sortTasks([created, ..._current]));
    return created;
  }

  Future<void> toggleTask(GroupTaskResponse task) async {
    final updatedCompleted = !task.isCompleted;
    final next = task.copyWith(isCompleted: updatedCompleted);
    _applyLocalTask(next);
    try {
      final saved = await _repo.updateTask(
        arg,
        task.id,
        GroupTaskUpdate(isCompleted: updatedCompleted),
      );
      _applyLocalTask(saved.copyWith(subtasks: task.subtasks));
    } catch (_) {
      _applyLocalTask(task);
      rethrow;
    }
  }

  Future<GroupTaskResponse> updateTask(
      int taskId, GroupTaskUpdate body) async {
    final updated = await _repo.updateTask(arg, taskId, body);
    _applyLocalTask(updated);
    return updated;
  }

  Future<void> deleteTask(int taskId) async {
    final before = _current;
    state = AsyncData(before.where((t) => t.id != taskId).toList());
    try {
      await _repo.deleteTask(arg, taskId);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }

  // --- Subtasks within Group Tasks ---

  Future<void> fetchSubtasks(int taskId) async {
    try {
      final subtasks = await _repo.subtasks(arg, taskId);
      final list = _current;
      final idx = list.indexWhere((t) => t.id == taskId);
      if (idx >= 0) {
        final copy = [...list]..[idx] = list[idx].copyWith(subtasks: subtasks);
        state = AsyncData(copy);
      }
    } catch (_) {
      // Keep existing
    }
  }

  Future<GroupSubtaskResponse> createSubtask(
      int taskId, String title) async {
    final subtask =
        await _repo.createSubtask(arg, taskId, GroupSubtaskCreate(title: title));
    final list = _current;
    final idx = list.indexWhere((t) => t.id == taskId);
    if (idx >= 0) {
      final updatedSubtasks = [...list[idx].subtasks, subtask];
      final copy = [...list]..[idx] =
          list[idx].copyWith(subtasks: updatedSubtasks);
      state = AsyncData(copy);
    }
    return subtask;
  }

  Future<void> toggleSubtask(
      int taskId, GroupSubtaskResponse subtask) async {
    final updatedCompleted = !subtask.isCompleted;
    final toggled = subtask.copyWith(isCompleted: updatedCompleted);

    _applyLocalSubtask(taskId, toggled);
    try {
      final saved = await _repo.updateSubtask(
        arg,
        subtask.id,
        GroupSubtaskUpdate(isCompleted: updatedCompleted),
      );
      _applyLocalSubtask(taskId, saved);
    } catch (_) {
      _applyLocalSubtask(taskId, subtask);
      rethrow;
    }
  }

  Future<void> deleteSubtask(int taskId, int subtaskId) async {
    final list = _current;
    final idx = list.indexWhere((t) => t.id == taskId);
    if (idx < 0) return;
    final oldSubtasks = list[idx].subtasks;
    final filtered = oldSubtasks.where((s) => s.id != subtaskId).toList();
    final copy = [...list]..[idx] = list[idx].copyWith(subtasks: filtered);
    state = AsyncData(copy);

    try {
      await _repo.deleteSubtask(arg, subtaskId);
    } catch (_) {
      final reverted = [...list]..[idx] =
          list[idx].copyWith(subtasks: oldSubtasks);
      state = AsyncData(reverted);
      rethrow;
    }
  }

  void _applyLocalTask(GroupTaskResponse task) {
    final list = _current;
    final idx = list.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      final copy = [...list]..[idx] = task;
      state = AsyncData(_sortTasks(copy));
    }
  }

  void _applyLocalSubtask(int taskId, GroupSubtaskResponse subtask) {
    final list = _current;
    final idx = list.indexWhere((t) => t.id == taskId);
    if (idx >= 0) {
      final subtasks = [...list[idx].subtasks];
      final subIdx = subtasks.indexWhere((s) => s.id == subtask.id);
      if (subIdx >= 0) {
        subtasks[subIdx] = subtask;
      }
      final copy = [...list]..[idx] = list[idx].copyWith(subtasks: subtasks);
      state = AsyncData(copy);
    }
  }

  static List<GroupTaskResponse> _sortTasks(List<GroupTaskResponse> list) {
    final copy = [...list];
    copy.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      if (a.dueDate != null && b.dueDate != null) {
        final d = a.dueDate!.compareTo(b.dueDate!);
        if (d != 0) return d;
      } else if (a.dueDate != null) {
        return -1;
      } else if (b.dueDate != null) {
        return 1;
      }
      return b.priority.index.compareTo(a.priority.index);
    });
    return copy;
  }
}

final groupTasksControllerProvider = AsyncNotifierProvider.family<
    GroupTasksController, List<GroupTaskResponse>, int>(
  GroupTasksController.new,
);

// ---------------------------------------------------------------------------
// Received Invitations Controller
// ---------------------------------------------------------------------------

class InvitationsController
    extends AsyncNotifier<List<InGroupInvitationResponse>> {
  InvitationRepository get _repo => ref.read(invitationRepositoryProvider);
  List<InGroupInvitationResponse> get _current =>
      state.valueOrNull ?? const <InGroupInvitationResponse>[];

  @override
  Future<List<InGroupInvitationResponse>> build() async {
    final uid =
        ref.watch(currentUserProvider.select((u) => u?.id ?? u?.email));
    if (uid == null) return const <InGroupInvitationResponse>[];
    return await _repo.getInvitations();
  }

  Future<void> refresh() async {
    try {
      final list = await _repo.getInvitations();
      state = AsyncData(list);
    } catch (e, st) {
      if (!state.hasValue) state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<InGroupInvitationResponse> respond(
    int invitationId,
    InvitationStatus status,
  ) async {
    final updated = await _repo.respond(invitationId, status);
    final list = _current;
    final idx = list.indexWhere((i) => i.id == invitationId);
    if (idx >= 0) {
      final copy = [...list]..[idx] = updated;
      state = AsyncData(copy);
    } else {
      state = AsyncData([updated, ...list]);
    }
    if (status == InvitationStatus.accepted) {
      await ref.read(groupsControllerProvider.notifier).refresh();
    }
    return updated;
  }
}

final invitationsControllerProvider = AsyncNotifierProvider<
    InvitationsController, List<InGroupInvitationResponse>>(
  InvitationsController.new,
);
