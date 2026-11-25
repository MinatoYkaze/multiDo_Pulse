import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Every `/groups/*` endpoint of the FastAPI spec.
class GroupsRepository {
  GroupsRepository(this._api);
  final ApiClient _api;

  static Map<String, dynamic>? _map(dynamic d) =>
      d is Map && d['id'] != null ? Map<String, dynamic>.from(d) : null;
  static Group? _group(dynamic d) {
    final m = _map(d);
    return m == null ? null : Group.fromJson(m);
  }

  static GroupTaskResponse? _task(dynamic d) {
    final m = _map(d);
    return m == null ? null : GroupTaskResponse.fromJson(m);
  }

  static GroupSubtaskResponse? _sub(dynamic d) {
    final m = _map(d);
    return m == null ? null : GroupSubtaskResponse.fromJson(m);
  }

  // ── groups ──
  Future<List<Group>> groups() =>
      _api.get(Api.groups, parse: (d) => ApiClient.list(d, Group.fromJson));
  Future<Group> group(int id) =>
      _api.get(Api.group(id), parse: (d) => ApiClient.obj(d, Group.fromJson));
  Future<Group?> create(GroupPost b) =>
      _api.post(Api.groups, body: b.toJson(), parse: _group);
  Future<Group?> update(int id, UpdateGroup b) =>
      _api.patch(Api.group(id), body: b.toJson(), parse: _group);
  Future<void> delete(int id) => _api.delete(Api.group(id), parse: (_) {});

  // ── tasks ──
  Future<List<GroupTaskResponse>> tasks(int g) => _api.get(Api.groupTasks(g),
      parse: (d) => ApiClient.list(d, GroupTaskResponse.fromJson));
  Future<List<GroupTaskResponse>> myTasks(int g) => _api.get(
      Api.groupMyTasks(g),
      parse: (d) => ApiClient.list(d, GroupTaskResponse.fromJson));
  Future<GroupTaskResponse> task(int g, int t) => _api.get(Api.groupTask(g, t),
      parse: (d) => ApiClient.obj(d, GroupTaskResponse.fromJson));
  Future<GroupTaskResponse?> createTask(int g, GroupTasksCreate b) =>
      _api.post(Api.groupTasks(g), body: b.toJson(), parse: _task);
  Future<GroupTaskResponse?> updateTask(int g, int t, GroupTaskUpdate b) =>
      _api.patch(Api.groupTask(g, t), body: b.toJson(), parse: _task);
  Future<void> deleteTask(int g, int t) =>
      _api.delete(Api.groupTask(g, t), parse: (_) {});

  // ── subtasks ──
  Future<List<GroupSubtaskResponse>> subtasks(int g, int t) => _api.get(
      Api.groupSubtasks(g, t),
      parse: (d) => ApiClient.list(d, GroupSubtaskResponse.fromJson));
  Future<GroupSubtaskResponse?> addSubtask(int g, int t, GroupSubtaskCreate b) =>
      _api.post(Api.groupSubtasks(g, t), body: b.toJson(), parse: _sub);
  Future<GroupSubtaskResponse?> updateSubtask(int g, int s, GroupSubtaskUpdate b) =>
      _api.patch(Api.groupSubtask(g, s), body: b.toJson(), parse: _sub);
  Future<void> deleteSubtask(int g, int s) =>
      _api.delete(Api.groupSubtask(g, s), parse: (_) {});

  // ── members & invitations ──
  Future<List<GroupMemberResponse>> members(int g) => _api.get(
      Api.groupMembers(g),
      parse: (d) => ApiClient.list(d, GroupMemberResponse.fromJson));
  Future<GroupInvitationResponse> invite(int g, GroupInvitationBase b) =>
      _api.post(Api.groupInvite(g),
          body: b.toJson(),
          parse: (d) => ApiClient.obj(d, GroupInvitationResponse.fromJson));
  Future<void> leave(int g) => _api.post<void>(Api.groupLeave(g), parse: (_) {});
  Future<void> removeMember(int g, int userId) =>
      _api.delete(Api.groupMember(g, userId), parse: (_) {});
}

final groupsRepositoryProvider = Provider<GroupsRepository>(
    (ref) => GroupsRepository(ref.watch(apiClientProvider)));
