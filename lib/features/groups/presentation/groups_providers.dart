import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/storage/offline_cache.dart';
import '../../../core/theme/theme_controller.dart';
import '../../analytics/data/activity_log.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/groups_repository.dart';

// ═════════════════════════ groups list ═════════════════════════

class GroupsController extends AsyncNotifier<List<Group>> {
  GroupsRepository get _repo => ref.read(groupsRepositoryProvider);
  OfflineCache get _cache => ref.read(offlineCacheProvider);
  List<Group> get _cur => state.valueOrNull ?? const [];

  @override
  Future<List<Group>> build() async {
    final cached = _cache.getGroups();
    if (cached.isNotEmpty) {
      state = AsyncData(cached);
    }
    try {
      final fresh = await _repo.groups();
      await _cache.saveGroups(fresh);
      return fresh;
    } catch (e, s) {
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> reload() async {
    try {
      final fresh = await _repo.groups();
      state = AsyncData(fresh);
      await _cache.saveGroups(fresh);
    } catch (e, s) {
      if (!state.hasValue) state = AsyncError(e, s);
    }
  }

  Future<void> create(GroupPost b) async {
    final g = await _repo.create(b);
    if (g == null) {
      await reload();
    } else {
      final next = [g, ..._cur];
      state = AsyncData(next);
      await _cache.saveGroups(next);
    }
  }

  Future<void> edit(Group g, UpdateGroup b) async {
    final old = _cur;
    final updated = [
      for (final x in old)
        x.id == g.id
            ? Group(
                id: x.id,
                name: b.name ?? x.name,
                description: b.description ?? x.description,
                ownerId: x.ownerId,
                createdAt: x.createdAt,
                memberCount: x.memberCount,
                taskCount: x.taskCount,
                completedTaskCount: x.completedTaskCount)
            : x
    ];
    state = AsyncData(updated);
    await _cache.saveGroups(updated);
    try {
      await _repo.update(g.id, b);
    } catch (_) {
      state = AsyncData(old);
      await _cache.saveGroups(old);
      rethrow;
    }
  }

  /// Deletes on the server first, then drops it locally.
  Future<void> remove(int id) async {
    await _repo.delete(id);
    final updated = _cur.where((g) => g.id != id).toList();
    state = AsyncData(updated);
    await _cache.saveGroups(updated);
    ref.invalidate(groupTasksProvider(id));
  }

  void dropLocal(int id) {
    final updated = _cur.where((g) => g.id != id).toList();
    state = AsyncData(updated);
    _cache.saveGroups(updated);
  }
}

final groupsControllerProvider =
    AsyncNotifierProvider<GroupsController, List<Group>>(GroupsController.new);

enum GroupFilter { all, active, completed }

final groupFilterProvider = StateProvider<GroupFilter>((_) => GroupFilter.all);

/// Single group (uses the list cache, falls back to GET /groups/{id}).
final groupDetailProvider =
    FutureProvider.autoDispose.family<Group, int>((ref, id) async {
  final cached = ref
      .watch(groupsControllerProvider)
      .valueOrNull
      ?.firstWhereOrNull((g) => g.id == id);
  if (cached != null) return cached;
  return ref.read(groupsRepositoryProvider).group(id);
});

/// Pin state is local-only (the API has no pin field), persisted in prefs.
class PinnedGroups extends Notifier<Set<int>> {
  static const _k = 'pinned_groups';
  @override
  Set<int> build() => (ref.read(sharedPrefsProvider).getStringList(_k) ?? const [])
      .map(int.tryParse)
      .whereType<int>()
      .toSet();

  void toggle(int id) {
    final next = {...state};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = next;
    ref
        .read(sharedPrefsProvider)
        .setStringList(_k, next.map((e) => e.toString()).toList());
  }
}

final pinnedGroupsProvider =
    NotifierProvider<PinnedGroups, Set<int>>(PinnedGroups.new);

// ═════════════════════════ group tasks ═════════════════════════

class GroupTasksController
    extends FamilyAsyncNotifier<List<GroupTaskResponse>, int> {
  GroupsRepository get _repo => ref.read(groupsRepositoryProvider);
  OfflineCache get _cache => ref.read(offlineCacheProvider);
  List<GroupTaskResponse> get _cur => state.valueOrNull ?? const [];
  DateTime lastSync = DateTime.now();

  @override
  Future<List<GroupTaskResponse>> build(int arg) async {
    final cached = _cache.getGroupTasks(arg);
    if (cached.isNotEmpty) {
      state = AsyncData(cached);
    }
    try {
      final r = await _repo.tasks(arg);
      lastSync = DateTime.now();
      await _cache.saveGroupTasks(arg, r);
      return r;
    } catch (e, s) {
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  void _refreshMine() => ref.invalidate(myGroupTasksProvider(arg));

  Future<void> reload() async {
    try {
      final fresh = await _repo.tasks(arg);
      state = AsyncData(fresh);
      lastSync = DateTime.now();
      await _cache.saveGroupTasks(arg, fresh);
      _refreshMine();
    } catch (e, s) {
      if (!state.hasValue) state = AsyncError(e, s);
    }
  }

  void _patch(GroupTaskResponse t) {
    final updated = [for (final x in _cur) x.id == t.id ? t : x];
    state = AsyncData(updated);
    _cache.saveGroupTasks(arg, updated);
  }

  Future<void> add(GroupTasksCreate b) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final local = GroupTaskResponse(
      id: tempId,
      groupId: arg,
      title: b.title,
      description: b.description,
      priority: b.priority,
      isCompleted: false,
      dueDate: b.dueDate,
      assignedTo: b.assignedTo,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final next = [local, ..._cur];
    state = AsyncData(next);
    await _cache.saveGroupTasks(arg, next);
    _refreshMine();

    try {
      final t = await _repo.createTask(arg, b);
      if (t != null) {
        final cur = state.valueOrNull ?? next;
        final replaced = cur.map((x) => x.id == tempId ? t : x).toList();
        state = AsyncData(replaced);
        await _cache.saveGroupTasks(arg, replaced);
        _refreshMine();
      }
    } catch (_) {}
  }

  Future<void> toggle(GroupTaskResponse t) async {
    final next = t.copyWith(isCompleted: !t.isCompleted);
    _patch(next);
    final log = ref.read(activityLogProvider.notifier);
    next.isCompleted ? log.logDone('g:$arg:${t.id}') : log.undo('g:$arg:${t.id}');
    if (t.id < 0) return;
    try {
      await _repo.updateTask(arg, t.id, GroupTaskUpdate(isCompleted: next.isCompleted));
      _refreshMine();
    } catch (_) {}
  }

  Future<void> edit(GroupTaskResponse t, GroupTaskUpdate b) async {
    final applied = GroupTaskResponse(
      id: t.id,
      groupId: t.groupId,
      title: b.title ?? t.title,
      description: b.description ?? t.description,
      priority: b.priority ?? t.priority,
      isCompleted: b.isCompleted ?? t.isCompleted,
      dueDate: b.dueDate ?? t.dueDate,
      assignedTo: b.assignedTo ?? t.assignedTo,
      assigneeName: b.assignedTo != null ? null : t.assigneeName,
      createdBy: t.createdBy,
      createdAt: t.createdAt,
      updatedAt: DateTime.now(),
      subtasks: t.subtasks,
    );
    _patch(applied);
    try {
      final server = await _repo.updateTask(arg, t.id, b);
      if (server != null) _patch(server);
      _refreshMine();
    } catch (_) {
      _patch(t);
      rethrow;
    }
  }

  Future<void> remove(GroupTaskResponse t) async {
    final old = _cur;
    final updated = old.where((x) => x.id != t.id).toList();
    state = AsyncData(updated);
    await _cache.saveGroupTasks(arg, updated);
    _refreshMine();
    if (t.id < 0) return;
    try {
      await _repo.deleteTask(arg, t.id);
    } catch (_) {}
  }
}

final groupTasksProvider = AsyncNotifierProvider.family<GroupTasksController,
    List<GroupTaskResponse>, int>(GroupTasksController.new);

/// GET /groups/{id}/my-tasks
final myGroupTasksProvider = FutureProvider.autoDispose
    .family<List<GroupTaskResponse>, int>((ref, g) =>
        ref.read(groupsRepositoryProvider).myTasks(g));

class GroupStats {
  const GroupStats(this.total, this.done, this.critical);
  final int total, done, critical;
  int get pending => total - done;
  double get progress => total == 0 ? 0 : done / total;
  int get percent => (progress * 100).round();
  bool get complete => total > 0 && done == total;

  factory GroupStats.of(List<GroupTaskResponse> l) => GroupStats(
        l.length,
        l.where((t) => t.isCompleted).length,
        l.where((t) => !t.isCompleted && t.priority == Priority.high).length,
      );
}

/// null while the group's tasks are still loading / failed.
final groupStatsProvider = Provider.family<GroupStats?, int>((ref, id) {
  final l = ref.watch(groupTasksProvider(id)).valueOrNull;
  return l == null ? null : GroupStats.of(l);
});

// ═════════════════════════ subtasks ═════════════════════════

typedef GroupTaskKey = ({int groupId, int taskId});

class GroupSubtasksController extends AutoDisposeFamilyAsyncNotifier<
    List<GroupSubtaskResponse>, GroupTaskKey> {
  GroupsRepository get _repo => ref.read(groupsRepositoryProvider);
  List<GroupSubtaskResponse> get _cur => state.valueOrNull ?? const [];

  @override
  Future<List<GroupSubtaskResponse>> build(GroupTaskKey arg) =>
      _repo.subtasks(arg.groupId, arg.taskId);

  Future<void> add(String title) async {
    final s = await _repo.addSubtask(
        arg.groupId, arg.taskId, GroupSubtaskCreate(title: title));
    if (s == null) {
      state = AsyncData(await _repo.subtasks(arg.groupId, arg.taskId));
    } else {
      state = AsyncData([..._cur, s]);
    }
  }

  List<GroupSubtaskResponse> _swap(GroupSubtaskResponse s) =>
      [for (final x in _cur) x.id == s.id ? s : x];

  Future<void> toggle(GroupSubtaskResponse s) async {
    final old = _cur;
    final next = s.copyWith(isCompleted: !s.isCompleted);
    state = AsyncData(_swap(next));
    try {
      await _repo.updateSubtask(
          arg.groupId, s.id, GroupSubtaskUpdate(isCompleted: next.isCompleted));
    } catch (_) {
      state = AsyncData(old);
      rethrow;
    }
  }

  Future<void> rename(GroupSubtaskResponse s, String title) async {
    final old = _cur;
    state = AsyncData(_swap(s.copyWith(title: title)));
    try {
      await _repo.updateSubtask(arg.groupId, s.id, GroupSubtaskUpdate(title: title));
    } catch (_) {
      state = AsyncData(old);
      rethrow;
    }
  }

  Future<void> remove(GroupSubtaskResponse s) async {
    final old = _cur;
    state = AsyncData(old.where((x) => x.id != s.id).toList());
    try {
      await _repo.deleteSubtask(arg.groupId, s.id);
    } catch (_) {
      state = AsyncData(old);
      rethrow;
    }
  }
}

final groupSubtasksProvider = AsyncNotifierProvider.autoDispose.family<
    GroupSubtasksController,
    List<GroupSubtaskResponse>,
    GroupTaskKey>(GroupSubtasksController.new);

// ═════════════════════════ members ═════════════════════════

class GroupMembersController
    extends AutoDisposeFamilyAsyncNotifier<List<GroupMemberResponse>, int> {
  GroupsRepository get _repo => ref.read(groupsRepositoryProvider);

  @override
  Future<List<GroupMemberResponse>> build(int arg) => _repo.members(arg);

  Future<void> reload() async {
    try {
      state = AsyncData(await _repo.members(arg));
    } catch (_) {}
  }

  Future<GroupInvitationResponse> invite(String email, Role role) =>
      _repo.invite(arg, GroupInvitationBase(email: email, role: role));

  Future<void> remove(GroupMemberResponse m) async {
    final old = state.valueOrNull ?? const [];
    state = AsyncData(old.where((x) => x.userId != m.userId).toList());
    try {
      await _repo.removeMember(arg, m.userId);
    } catch (_) {
      state = AsyncData(old);
      rethrow;
    }
  }

  Future<void> leave() => _repo.leave(arg);
}

final groupMembersProvider = AsyncNotifierProvider.autoDispose
    .family<GroupMembersController, List<GroupMemberResponse>, int>(
        GroupMembersController.new);

/// Current user's id as the backend sees it (UserPost.id is a string).
final myUserIdProvider = Provider<int?>(
    (ref) => int.tryParse(ref.watch(currentUserProvider)?.id ?? ''));

/// Current user's role in a group (null until members/group are known).
final myRoleProvider = Provider.autoDispose.family<Role?, int>((ref, g) {
  final user = ref.watch(currentUserProvider);
  final uid = ref.watch(myUserIdProvider);
  final members = ref.watch(groupMembersProvider(g)).valueOrNull;
  final me = members?.firstWhereOrNull((m) =>
      (uid != null && m.userId == uid) ||
      (user?.email != null && m.email == user!.email));
  if (me != null) return me.role;
  final grp = ref
      .watch(groupsControllerProvider)
      .valueOrNull
      ?.firstWhereOrNull((x) => x.id == g);
  if (uid != null && grp?.ownerId == uid) return Role.owner;
  return null;
});
