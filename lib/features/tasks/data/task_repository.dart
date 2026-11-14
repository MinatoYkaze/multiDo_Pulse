import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Personal tasks + subtasks (`/tasks/*`).
///
/// Write endpoints may answer with the saved object or with an empty / message
/// body, so they return a nullable model; controllers fall back to local state.
class TaskRepository {
  TaskRepository(this._api);
  final ApiClient _api;

  static Tasks? _task(dynamic d) => d is Map && d['id'] != null
      ? Tasks.fromJson(Map<String, dynamic>.from(d))
      : null;

  static SubtaskResponse? _sub(dynamic d) => d is Map && d['id'] != null
      ? SubtaskResponse.fromJson(Map<String, dynamic>.from(d))
      : null;

  /// GET /tasks/
  Future<List<Tasks>> list() => _api.get<List<Tasks>>(Api.tasks,
      parse: (d) => ApiClient.list(d, Tasks.fromJson));

  /// GET /tasks/{id}
  Future<Tasks> get(int id) => _api.get<Tasks>(Api.task(id),
      parse: (d) => ApiClient.obj(d, Tasks.fromJson));

  /// POST /tasks/
  Future<Tasks?> create(TasksPost body) =>
      _api.post<Tasks?>(Api.tasks, body: body.toJson(), parse: _task);

  /// PUT /tasks/{id}
  Future<Tasks?> update(int id, TasksPost body) =>
      _api.put<Tasks?>(Api.task(id), body: body.toJson(), parse: _task);

  /// DELETE /tasks/{id}
  Future<void> delete(int id) =>
      _api.delete<void>(Api.task(id), parse: (_) {});

  /// GET /tasks/{task_id}/subtasks
  Future<List<SubtaskResponse>> subtasks(int taskId) =>
      _api.get<List<SubtaskResponse>>(Api.subtasks(taskId),
          parse: (d) => ApiClient.list(d, SubtaskResponse.fromJson));

  /// POST /tasks/{task_id}/subtasks
  Future<SubtaskResponse?> addSubtask(int taskId, String title) =>
      _api.post<SubtaskResponse?>(Api.subtasks(taskId),
          body: SubtaskCreate(title: title).toJson(), parse: _sub);

  /// PUT /tasks/subtasks/{subtask_id}
  Future<SubtaskResponse?> updateSubtask(int id, SubtaskUpdate body) =>
      _api.put<SubtaskResponse?>(Api.subtask(id),
          body: body.toJson(), parse: _sub);

  /// DELETE /tasks/subtasks/{subtask_id}
  Future<void> deleteSubtask(int id) =>
      _api.delete<void>(Api.subtask(id), parse: (_) {});
}

final taskRepositoryProvider = Provider<TaskRepository>(
    (ref) => TaskRepository(ref.watch(apiClientProvider)));
