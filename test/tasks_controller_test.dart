import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/models/models.dart';
import 'package:obsidian_todo/core/network/api_client.dart';
import 'package:obsidian_todo/core/storage/offline_cache.dart';
import 'package:obsidian_todo/features/auth/presentation/auth_controller.dart';
import 'package:obsidian_todo/features/tasks/data/task_repository.dart';
import 'package:obsidian_todo/features/tasks/presentation/tasks_controller.dart';

class MockTaskRepo implements TaskRepository {
  List<Tasks> tasks = [
    Tasks(id: 1, title: 'Task 1', isCompleted: false),
  ];

  @override
  Future<List<Tasks>> list() async => tasks;

  @override
  Future<Tasks?> update(int id, TasksPost body) async {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      final updated = tasks[idx].copyWith(isCompleted: body.isCompleted);
      tasks[idx] = updated;
      return updated;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOfflineCache implements OfflineCache {
  List<Tasks> cached = [];

  @override
  List<Tasks> getTasks() => cached;

  @override
  Future<void> saveTasks(List<Tasks> list) async {
    cached = list;
  }

  @override
  List<Map<String, dynamic>> getPendingActions() => [];

  @override
  Future<void> addPendingAction(Map<String, dynamic> a) async {}

  @override
  Future<void> removePendingAction(String a) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('tasksControllerProvider toggle toggles completion and updates visibleTasks', () async {
    final mockRepo = MockTaskRepo();
    final mockCache = MockOfflineCache();

    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => const UserPost(id: '1', email: 'test@test.com', name: 'Test')),
        taskRepositoryProvider.overrideWithValue(mockRepo),
        offlineCacheProvider.overrideWithValue(mockCache),
      ],
    );

    // Initial build
    final initial = await container.read(tasksControllerProvider.future);
    expect(initial.first.isCompleted, isFalse);

    final visibleInitial = container.read(visibleTasksProvider);
    expect(visibleInitial.first.isCompleted, isFalse);

    // Toggle task 1
    await container.read(tasksControllerProvider.notifier).toggle(initial.first);

    final toggled = container.read(tasksControllerProvider).valueOrNull!;
    expect(toggled.first.isCompleted, isTrue);

    final visibleToggled = container.read(visibleTasksProvider);
    expect(visibleToggled.first.isCompleted, isTrue);
  });
}
