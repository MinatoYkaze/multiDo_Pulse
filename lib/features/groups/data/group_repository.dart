import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class GroupRepository {
  GroupRepository(this._api);
  final ApiClient _api;

  // --- Group CRUD ---

  /// GET /groups/
  Future<List<Group>> list() => _api.get(
        Api.groups,
        parse: (d) => ApiClient.list(d, Group.fromJson),
      );

  /// GET /groups/{id}
  Future<Group> get(int id) => _api.get(
        Api.group(id),
        parse: (d) => ApiClient.obj(d, Group.fromJson),
      );

  /// POST /groups/
  Future<Group> create(GroupPost body) => _api.post(
        Api.groups,
        body: body.toJson(),
        parse: (d) => ApiClient.obj(d, Group.fromJson),
      );

  /// PUT /groups/{id}
  Future<Group> update(int id, UpdateGroup body) => _api.put(
        Api.group(id),
        body: body.toJson(),
        parse: (d) => ApiClient.obj(d, Group.fromJson),
      );

  /// DELETE /groups/{id}
  Future<void> delete(int id) =>
      _api.delete<void>(Api.group(id), parse: (_) {});

  // --- Members & Invitations ---

  /// GET /groups/{group_id}/members
  Future<List<GroupMemberResponse>> members(int groupId) => _api.get(
        Api.groupMembers(groupId),
        parse: (d) => ApiClient.list(d, GroupMemberResponse.fromJson),
      );

  /// POST /groups/{group_id}/invite
  Future<InGroupInvitationResponse> invite(int groupId, String email) =>
      _api.post(
        Api.groupInvite(groupId),
        body: GroupInvitationBase(email: email).toJson(),
        parse: (d) => ApiClient.obj(d, InGroupInvitationResponse.fromJson),
      );

  /// POST /groups/{group_id}/leave
  Future<MessageResponse> leave(int groupId) => _api.post(
        Api.groupLeave(groupId),
        parse: (d) => ApiClient.obj(d, MessageResponse.fromJson),
      );

  /// DELETE /groups/{group_id}/members/{user_id}
  Future<MessageResponse> removeMember(int groupId, int userId) => _api.delete(
        Api.groupMember(groupId, userId),
        parse: (d) => ApiClient.obj(d, MessageResponse.fromJson),
      );

  // --- Tasks ---

  /// GET /groups/{group_id}/tasks
  Future<List<GroupTaskResponse>> tasks(int groupId) => _api.get(
        Api.groupTasks(groupId),
        parse: (d) => ApiClient.list(d, GroupTaskResponse.fromJson),
      );

  /// GET /groups/{group_id}/my-tasks
  Future<List<GroupTaskResponse>> myTasks(int groupId) => _api.get(
        Api.groupMyTasks(groupId),
        parse: (d) => ApiClient.list(d, GroupTaskResponse.fromJson),
      );

  /// POST /groups/{group_id}/tasks
  Future<GroupTaskResponse> createTask(int groupId, GroupTasksCreate body) =>
      _api.post(
        Api.groupTasks(groupId),
        body: body.toJson(),
        parse: (d) => ApiClient.obj(d, GroupTaskResponse.fromJson),
      );

  /// PATCH /groups/{group_id}/tasks/{task_id}
  Future<GroupTaskResponse> updateTask(
          int groupId, int taskId, GroupTaskUpdate body) =>
      _api.patch(
        Api.groupTask(groupId, taskId),
        body: body.toJson(),
        parse: (d) => ApiClient.obj(d, GroupTaskResponse.fromJson),
      );

  /// DELETE /groups/{group_id}/tasks/{task_id}
  Future<void> deleteTask(int groupId, int taskId) =>
      _api.delete<void>(Api.groupTask(groupId, taskId), parse: (_) {});

  // --- Subtasks ---

  /// GET /groups/{group_id}/tasks/{task_id}/subtasks
  Future<List<GroupSubtaskResponse>> subtasks(int groupId, int taskId) =>
      _api.get(
        Api.groupSubtasks(groupId, taskId),
        parse: (d) => ApiClient.list(d, GroupSubtaskResponse.fromJson),
      );

  /// POST /groups/{group_id}/tasks/{task_id}/subtasks
  Future<GroupSubtaskResponse> createSubtask(
          int groupId, int taskId, GroupSubtaskCreate body) =>
      _api.post(
        Api.groupSubtasks(groupId, taskId),
        body: body.toJson(),
        parse: (d) => ApiClient.obj(d, GroupSubtaskResponse.fromJson),
      );

  /// PATCH /groups/{group_id}/tasks/subtasks/{subtask_id}
  Future<GroupSubtaskResponse> updateSubtask(
          int groupId, int subtaskId, GroupSubtaskUpdate body) =>
      _api.patch(
        Api.groupSubtask(groupId, subtaskId),
        body: body.toJson(),
        parse: (d) => ApiClient.obj(d, GroupSubtaskResponse.fromJson),
      );

  /// DELETE /groups/{group_id}/tasks/subtasks/{subtask_id}
  Future<void> deleteSubtask(int groupId, int subtaskId) =>
      _api.delete<void>(Api.groupSubtask(groupId, subtaskId), parse: (_) {});
}

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => GroupRepository(ref.watch(apiClientProvider)),
);
