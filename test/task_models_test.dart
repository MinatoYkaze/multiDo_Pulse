import 'package:flutter_test/flutter_test.dart';
import 'package:obsidian_todo/core/models/models.dart';

void main() {
  test('TasksPost omits a null due date unless clearing it', () {
    expect(const TasksPost(title: 'a').toJson().containsKey('due_date'), false);
    final cleared = const TasksPost(title: 'a', clearDueDate: true).toJson();
    expect(cleared.containsKey('due_date'), true);
    expect(cleared['due_date'], isNull);
  });

  test('TasksPost.fromTask clears the deadline when the task has none', () {
    const t = Tasks(id: 1, title: 'x');
    expect(TasksPost.fromTask(t).toJson().containsKey('due_date'), true);
  });

  test('Tasks.copyWith can clear the due date', () {
    final t = Tasks(id: 1, title: 'x', dueDate: DateTime(2026, 11, 14));
    expect(t.copyWith(clearDueDate: true).dueDate, isNull);
    expect(t.copyWith(title: 'y').dueDate, t.dueDate);
  });
}
